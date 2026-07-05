--[[
    hrp_properties – Immobilien:
    - Kauf vom Staat (Bankzahlung, property.buy money-korreliert)
    - Schlüssel/Mitbewohner (property.key_grant)
    - Betreten: gemeinsames Shell-Interior, Isolation über ROUTING-BUCKETS
      (Bucket = property_id -> Bewohner verschiedener Wohnungen sehen sich nie)
    - Dynamische Preise: Kauf-Nachfrage pro Region hebt Preise, Tick lässt sie
      Richtung Basis zurücklaufen. Kriminalitäts-Score aus echten Log-Daten
      fließt in Phase 5 über das Backend in den Lage-Score ein.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

-- Gemeinsames Shell-Interior (Motel-Zimmer); pro Objekt isoliert via Bucket
local INTERIOR = vector4(151.3, -1007.6, -99.0, 0.0)
local BUCKET_BASE = 10000

-- inside[src] = propertyId
local inside = {}

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2IMMOBILIE' or '^1IMMOBILIE', msg } })
end

local function propertyNear(src, radius)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local rows = Db.query('SELECT * FROM properties') or {}
    for _, p in ipairs(rows) do
        if #(pos - vector3(p.entrance_x, p.entrance_y, p.entrance_z)) <= (radius or 3.0) then
            return p
        end
    end
    return nil
end

local function hasAccess(characterId, prop)
    if prop.owner_id == characterId then return true end
    return Db.scalar('SELECT 1 FROM property_keys WHERE property_id = ? AND character_id = ?',
        { prop.id, characterId }) ~= nil
end

-- ---------------------------------------------------------------------------
-- Kauf & Schlüssel
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:properties:buy', { rate = 0.3, burst = 2 }, function(src)
    local prop = propertyNear(src, 5.0)
    if not prop then return reply(src, false, 'Keine Immobilie in der Nähe.') end
    if prop.owner_id then return reply(src, false, 'Diese Immobilie ist bereits verkauft.') end

    local ident = Core:GetPlayerIdentity(src)
    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < prop.current_price then
        return reply(src, false, ('Kontostand zu niedrig (%s $ nötig).'):format(string.format('%.2f', prop.current_price / 100)))
    end

    local correlationId = Logger:NewCorrelationId()
    local paid = Core:MoneyDestroy(ident.characterId, 'bank', prop.current_price, 'property.buy',
        { correlationId = correlationId })
    if not paid then return reply(src, false, 'Zahlung fehlgeschlagen.') end

    Core:TreasuryCredit(prop.current_price, 'property.buy', { correlationId = correlationId })
    Db.update('UPDATE properties SET owner_id = ?, purchased_at = NOW(3) WHERE id = ?',
        { ident.characterId, prop.id })

    -- Nachfrage-Signal: Käufe heben Preise der Region
    local demandBump = Core:TuningGet('properties.demand_price_bump', 0.03)
    Db.update('UPDATE properties SET current_price = FLOOR(current_price * (1 + ?)) WHERE region = ? AND owner_id IS NULL',
        { demandBump, prop.region })

    Core:Log(src, 'property.buy', {
        target = { kind = 'property', id = tostring(prop.id) },
        correlationId = correlationId,
        payload = { propertyId = prop.id, label = prop.label, region = prop.region,
                    price = prop.current_price, ownerId = ident.characterId },
    })
    reply(src, true, ('Gekauft: %s für %s $.'):format(prop.label, string.format('%.2f', prop.current_price / 100)))
end)

Core:RegisterSecureEvent('hrp:properties:giveKey', {
    rate = 0.5, burst = 2,
    schema = { { type = 'number', integer = true, min = 1 } },
}, function(src, targetSrc)
    local prop = propertyNear(src, 5.0)
    if not prop then return reply(src, false, 'Keine Immobilie in der Nähe.') end
    local ident = Core:GetPlayerIdentity(src)
    if prop.owner_id ~= ident.characterId then return reply(src, false, 'Du bist nicht der Eigentümer.') end

    local target = Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 5.0 then
        return reply(src, false, 'Der Spieler ist zu weit weg.')
    end

    Db.update('INSERT IGNORE INTO property_keys (property_id, character_id, granted_by) VALUES (?, ?, ?)',
        { prop.id, target.characterId, ident.characterId })

    Core:Log(src, 'property.key_grant', {
        target = { kind = 'property', id = tostring(prop.id) },
        payload = { propertyId = prop.id, fromCharacterId = ident.characterId,
                    toCharacterId = target.characterId },
    })
    reply(src, true, 'Schlüssel übergeben.')
    reply(targetSrc, true, ('Du hast einen Wohnungsschlüssel erhalten: %s'):format(prop.label))
end)

-- ---------------------------------------------------------------------------
-- Betreten / Verlassen (Routing-Buckets)
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:properties:enter', { rate = 0.5, burst = 3 }, function(src)
    if inside[src] then return end
    local prop = propertyNear(src, 3.0)
    if not prop then return reply(src, false, 'Keine Immobilie in der Nähe.') end

    local ident = Core:GetPlayerIdentity(src)
    if not hasAccess(ident.characterId, prop) then
        Core:Log(src, 'door.access', {
            target = { kind = 'property', id = tostring(prop.id) },
            payload = { propertyId = prop.id, result = 'denied', characterId = ident.characterId },
        })
        return reply(src, false, 'Du hast keinen Schlüssel.')
    end

    inside[src] = prop.id
    SetPlayerRoutingBucket(src, BUCKET_BASE + prop.id)
    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 10000) end)
    TriggerClientEvent('hrp:properties:teleport', src,
        { x = INTERIOR.x, y = INTERIOR.y, z = INTERIOR.z, h = INTERIOR.w })

    Core:Log(src, 'door.access', {
        target = { kind = 'property', id = tostring(prop.id) },
        payload = { propertyId = prop.id, result = 'granted', characterId = ident.characterId },
    })
end)

Core:RegisterSecureEvent('hrp:properties:leave', { rate = 0.5, burst = 3 }, function(src)
    local propId = inside[src]
    if not propId then return end
    local prop = Db.single('SELECT * FROM properties WHERE id = ?', { propId })
    inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 10000) end)
    if prop then
        TriggerClientEvent('hrp:properties:teleport', src,
            { x = prop.entrance_x, y = prop.entrance_y, z = prop.entrance_z, h = 0.0 })
    end
end)

AddEventHandler('playerDropped', function()
    inside[source] = nil
end)

-- Preis-Tick: unbesetzte Objekte laufen Richtung Basispreis zurück
CreateThread(function()
    while true do
        local minutes = Core:TuningGet('properties.price_tick_minutes', 60)
        Wait(math.max(5, minutes) * 60000)
        local reversion = Core:TuningGet('properties.price_reversion', 0.02)
        Db.update([[
            UPDATE properties
            SET current_price = FLOOR(current_price + (base_price - current_price) * ?)
            WHERE owner_id IS NULL
        ]], { reversion })
    end
end)
