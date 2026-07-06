--[[
    hrp_inventory – Item-Instanzen mit vollständigem Lebenszyklus.

    Jede physische Item-Einheit (bzw. Stack) ist eine Instanz mit UUID.
    JEDE Mutation läuft über die Inventory.*-API, die DB-Änderung und
    item.*-Event koppelt (Kernprinzip A). Instanzen werden NIE hart gelöscht
    (destroyed_at = Soft-Delete) -> Item-Trace bleibt vollständig.
]]

Inventory = {}

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local MAX_CARRY_GRAMS = GetConvarInt('hrp_max_carry_grams', 30000) -- 30 kg

-- Definitions-Cache (Reload via Konsole: hrp_inventory_reload)
local definitions = {}

local function loadDefinitions()
    definitions = {}
    for _, row in ipairs(Db.query('SELECT * FROM item_definitions') or {}) do
        definitions[row.name] = row
    end
    print(('[hrp_inventory] %d Item-Definitionen geladen.'):format(#(Db.query('SELECT id FROM item_definitions') or {})))
end

MySQL.ready(function()
    loadDefinitions()
end)

RegisterCommand('hrp_inventory_reload', function(src)
    if src ~= 0 then return end
    loadDefinitions()
end, true)

function Inventory.GetDefinition(name)
    return definitions[name]
end

-- ---------------------------------------------------------------------------
-- Gewicht / Kapazität
-- ---------------------------------------------------------------------------

--- Aktuelles Traggewicht eines Charakters in Gramm.
function Inventory.GetCarryWeight(characterId)
    return Db.scalar([[
        SELECT COALESCE(SUM(d.weight_grams * i.quantity), 0)
        FROM item_locations l
        JOIN item_instances i ON i.id = l.instance_id AND i.destroyed_at IS NULL
        JOIN item_definitions d ON d.id = i.definition_id
        WHERE l.container_type = 'character' AND l.container_id = ?
    ]], { tostring(characterId) })
end

local function canCarry(characterId, defName, quantity)
    local def = definitions[defName]
    if not def then return false end
    local current = Inventory.GetCarryWeight(characterId)
    return (current + def.weight_grams * quantity) <= MAX_CARRY_GRAMS
end

-- ---------------------------------------------------------------------------
-- Serien-Nummern (Waffen etc.)
-- ---------------------------------------------------------------------------

local function generateSerial()
    -- Format: 2 Buchstaben + 6 Ziffern, DB-Unique-Constraint sichert Kollision ab
    local letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    for _ = 1, 10 do
        local serial = letters:sub(math.random(1, 24), math.random(1, 24))
            .. letters:sub(math.random(1, 24), math.random(1, 24))
            .. string.format('%06d', math.random(0, 999999))
        local exists = Db.scalar('SELECT 1 FROM item_instances WHERE serial_number = ?', { serial })
        if not exists then return serial end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Lifecycle-API
-- ---------------------------------------------------------------------------

--- Item-Instanz erzeugen und in Container legen.
--- opts = {quality?, metadata?, createdBy?, correlationId?, srcForLog?}
--- container = {type='character'|'ground'|..., id=string}
--- Rückgabe: (uuid|nil, err)
function Inventory.Create(defName, quantity, reason, container, opts)
    opts = opts or {}
    local def = definitions[defName]
    if not def then return nil, 'unknown_definition' end
    if not HRPReasonsValid('item', reason) then return nil, 'unknown_reason' end
    quantity = math.floor(tonumber(quantity) or 0)
    if quantity < 1 or quantity > def.max_stack then return nil, 'invalid_quantity' end

    if container.type == 'character' and not canCarry(tonumber(container.id), defName, quantity) then
        return nil, 'too_heavy'
    end

    local uuid = Logger:NewCorrelationId() -- UUID-Generator wiederverwenden
    local serial = nil
    if def.is_unique == 1 then
        serial = generateSerial()
        if not serial then return nil, 'serial_exhausted' end
    end

    local instanceId = Db.insert([[
        INSERT INTO item_instances (uuid, definition_id, quantity, quality, serial_number, metadata, created_reason, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { uuid, def.id, quantity, opts.quality, serial,
          opts.metadata and json.encode(opts.metadata) or nil, reason, opts.createdBy })

    Db.insert([[
        INSERT INTO item_locations (instance_id, container_type, container_id)
        VALUES (?, ?, ?)
    ]], { instanceId, container.type, tostring(container.id) })

    Core:Log(opts.srcForLog, 'item.create', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = {
            uuid = uuid, definition = defName, quantity = quantity,
            quality = opts.quality, serialNumber = serial, reason = reason,
            container = { type = container.type, id = tostring(container.id) },
        },
    })
    return uuid
end

local function getInstance(uuid)
    return Db.single([[
        SELECT i.id, i.uuid, i.quantity, i.destroyed_at, d.name AS def_name, d.weight_grams,
               l.container_type, l.container_id
        FROM item_instances i
        JOIN item_definitions d ON d.id = i.definition_id
        LEFT JOIN item_locations l ON l.instance_id = i.id
        WHERE i.uuid = ?
    ]], { uuid })
end

--- FORENSIK: Wer ein Item aus der Hand gibt, hinterlässt mit Wahrscheinlichkeit
--- Fingerabdrücke in den Metadaten (max. 3, still — die Bewegung selbst ist das
--- Event). Auswertung nur mit Spuren-Kit durch die Polizei.
local function leavePrints(instanceId, characterId)
    local chance = 0.8
    pcall(function() chance = exports.hrp_core:TuningGet('inventory.print_chance', 0.8) end)
    if math.random() >= chance then return end

    local row = Db.single('SELECT metadata FROM item_instances WHERE id = ?', { instanceId })
    local meta = row and row.metadata and json.decode(row.metadata) or {}
    local prints = meta.prints or {}
    if prints[#prints] ~= characterId then
        prints[#prints + 1] = characterId
        while #prints > 3 do table.remove(prints, 1) end
    end
    meta.prints = prints
    Db.update('UPDATE item_instances SET metadata = ? WHERE id = ?', { json.encode(meta), instanceId })
end

--- Lagerbewegung (Inventar ↔ Kofferraum ↔ Boden ↔ Lager).
function Inventory.Move(uuid, toContainer, opts)
    opts = opts or {}
    local inst = getInstance(uuid)
    if not inst or inst.destroyed_at then return false, 'not_found' end

    if toContainer.type == 'character' then
        local charId = tonumber(toContainer.id)
        local current = Inventory.GetCarryWeight(charId)
        if current + inst.weight_grams * inst.quantity > MAX_CARRY_GRAMS then
            return false, 'too_heavy'
        end
    end

    Db.update([[
        UPDATE item_locations SET container_type = ?, container_id = ?, slot = NULL
        WHERE instance_id = ?
    ]], { toContainer.type, tostring(toContainer.id), inst.id })

    Core:Log(opts.srcForLog, 'item.move', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = {
            uuid = uuid,
            from = { type = inst.container_type, id = inst.container_id },
            to = { type = toContainer.type, id = tostring(toContainer.id) },
        },
    })
    -- Hook für Module mit Besitz-Bindung (z. B. hrp_weapons: Waffe entziehen)
    if inst.container_type == 'character' then
        leavePrints(inst.id, tonumber(inst.container_id))
        TriggerEvent('hrp:inventory:instanceMoved', uuid)
    end
    return true
end

--- Besitzerwechsel Charakter -> Charakter (Übergabe).
function Inventory.Transfer(uuid, fromCharacterId, toCharacterId, opts)
    opts = opts or {}
    local inst = getInstance(uuid)
    if not inst or inst.destroyed_at then return false, 'not_found' end
    if inst.container_type ~= 'character' or inst.container_id ~= tostring(fromCharacterId) then
        return false, 'not_owned'
    end

    local ok, err = Inventory.Move(uuid, { type = 'character', id = toCharacterId },
        { srcForLog = opts.srcForLog, correlationId = opts.correlationId })
    if not ok then return false, err end

    Core:Log(opts.srcForLog, 'item.transfer', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = { uuid = uuid, fromCharacterId = fromCharacterId,
                    toCharacterId = toCharacterId, quantity = inst.quantity },
    })
    return true
end

--- Verbrauch (Teilmenge). Bei Restmenge 0 wird die Instanz zerstört (Grund consume.use).
function Inventory.Consume(uuid, quantity, opts)
    opts = opts or {}
    local inst = getInstance(uuid)
    if not inst or inst.destroyed_at then return false, 'not_found' end
    quantity = math.floor(tonumber(quantity) or 0)
    if quantity < 1 or quantity > inst.quantity then return false, 'invalid_quantity' end

    local remaining = inst.quantity - quantity
    Db.update('UPDATE item_instances SET quantity = ? WHERE id = ?', { math.max(remaining, 0), inst.id })

    Core:Log(opts.srcForLog, 'item.consume', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = { uuid = uuid, quantityConsumed = quantity, quantityAfter = remaining },
    })

    if remaining == 0 then
        return Inventory.Destroy(uuid, 'consume.use', opts)
    end
    return true
end

--- Zerstörung (Soft-Delete, Instanz bleibt für Item-Trace erhalten).
function Inventory.Destroy(uuid, reason, opts)
    opts = opts or {}
    if not HRPReasonsValid('item', reason) then return false, 'unknown_reason' end
    local inst = getInstance(uuid)
    if not inst or inst.destroyed_at then return false, 'not_found' end

    Db.update('UPDATE item_instances SET destroyed_at = NOW(3), destroy_reason = ? WHERE id = ?', { reason, inst.id })
    Db.update("UPDATE item_locations SET container_type = 'none', container_id = '' WHERE instance_id = ?", { inst.id })

    Core:Log(opts.srcForLog, 'item.destroy', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = { uuid = uuid, reason = reason },
    })
    TriggerEvent('hrp:inventory:instanceMoved', uuid)
    return true
end

--- Metadaten/Qualität einer Instanz ändern (Merge) — z. B. geladene Munition,
--- Fingerabdrücke, Herkunft. Erzeugt item.modify mit Vorher/Nachher.
function Inventory.Modify(uuid, changes, reason, opts)
    opts = opts or {}
    local row = Db.single('SELECT id, quality, metadata, destroyed_at FROM item_instances WHERE uuid = ?', { uuid })
    if not row or row.destroyed_at then return false, 'not_found' end

    local before = { quality = row.quality, metadata = row.metadata and json.decode(row.metadata) or {} }
    local newMeta = before.metadata
    for k, v in pairs(changes.metadata or {}) do newMeta[k] = v end
    local newQuality = changes.quality ~= nil and changes.quality or row.quality

    Db.update('UPDATE item_instances SET quality = ?, metadata = ? WHERE id = ?',
        { newQuality, json.encode(newMeta), row.id })

    Core:Log(opts.srcForLog, 'item.modify', {
        target = { kind = 'item', id = uuid },
        correlationId = opts.correlationId,
        payload = {
            uuid = uuid, reason = reason or 'unspecified',
            before = before,
            after = { quality = newQuality, metadata = newMeta },
        },
    })
    return true
end

--- Inventar-Inhalt eines Containers.
function Inventory.GetContainer(containerType, containerId)
    return Db.query([[
        SELECT i.uuid, d.name, d.label, d.category, i.quantity, i.quality,
               i.serial_number, d.weight_grams
        FROM item_locations l
        JOIN item_instances i ON i.id = l.instance_id AND i.destroyed_at IS NULL
        JOIN item_definitions d ON d.id = i.definition_id
        WHERE l.container_type = ? AND l.container_id = ?
    ]], { containerType, tostring(containerId) })
end

-- Bodendrops verfallen nach Ablauf (Despawn -> item.destroy drop.despawn)
CreateThread(function()
    while true do
        Wait(300000)
        local ttlMinutes = 30
        pcall(function() ttlMinutes = exports.hrp_core:TuningGet('inventory.ground_despawn_minutes', 30) end)
        local expired = Db.query([[
            SELECT i.uuid FROM item_locations l
            JOIN item_instances i ON i.id = l.instance_id AND i.destroyed_at IS NULL
            WHERE l.container_type = 'ground' AND l.updated_at < DATE_SUB(NOW(3), INTERVAL ? MINUTE)
            LIMIT 100
        ]], { ttlMinutes }) or {}
        for _, row in ipairs(expired) do
            Inventory.Destroy(row.uuid, 'drop.despawn', {})
        end
    end
end)

-- Übergewicht: wer über dem Limit trägt, bewegt sich langsamer (Client-Flag)
local overweight = {}
CreateThread(function()
    while true do
        Wait(15000)
        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ok, ident = pcall(function() return exports.hrp_core:GetPlayerIdentity(src) end)
            if ok and ident and ident.characterId then
                local heavy = (Inventory.GetCarryWeight(ident.characterId) or 0) > MAX_CARRY_GRAMS
                if heavy ~= (overweight[src] or false) then
                    overweight[src] = heavy
                    TriggerClientEvent('hrp:inventory:overweight', src, heavy)
                end
            end
        end
    end
end)
AddEventHandler('playerDropped', function() overweight[source] = nil end)

-- HRPReasons lebt in hrp_core (shared) — hier über dessen Export gespiegelt,
-- damit die Reason-Registry eine einzige Quelle hat.
function HRPReasonsValid(category, code)
    return Core:IsValidReason(category, code)
end

--- Schusszähler einer Waffen-Instanz erhöhen (hrp_weapons; das zugehörige
--- combat.shot-Event erzeugt der Aufrufer mit Kontext).
function Inventory.AddShots(uuid, shots)
    return Db.update(
        'UPDATE item_instances SET shots_fired = shots_fired + ? WHERE uuid = ? AND destroyed_at IS NULL',
        { math.max(0, math.floor(shots)), uuid }) == 1
end

exports('AddShots', function(...) return Inventory.AddShots(...) end)
exports('Modify', function(...) return Inventory.Modify(...) end)
exports('GetInstanceMeta', function(uuid)
    local row = Db.single('SELECT quality, metadata, serial_number FROM item_instances WHERE uuid = ? AND destroyed_at IS NULL', { uuid })
    if not row then return nil end
    return { quality = row.quality, serialNumber = row.serial_number,
             metadata = row.metadata and json.decode(row.metadata) or {} }
end)
exports('Create', function(...) return Inventory.Create(...) end)
exports('Move', function(...) return Inventory.Move(...) end)
exports('Transfer', function(...) return Inventory.Transfer(...) end)
exports('Consume', function(...) return Inventory.Consume(...) end)
exports('Destroy', function(...) return Inventory.Destroy(...) end)
exports('GetContainer', function(...) return Inventory.GetContainer(...) end)
exports('GetCarryWeight', function(...) return Inventory.GetCarryWeight(...) end)
