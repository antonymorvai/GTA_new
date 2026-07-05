--[[
    hrp_characters: Multi-Charakter (max. 3 Slots), Erstellung mit
    Pflicht-Lebenslauf, Auswahl, Soft-Delete, Spawn und periodischer Save.
    Alle Mutationen -> character.*-Events (Katalog §character).
]]

local MAX_SLOTS = GetConvarInt('hrp_character_slots', 3)
local SAVE_INTERVAL = GetConvarInt('hrp_character_save_interval', 60000) -- ms
local STARTER_CASH = GetConvarInt('hrp_starter_cash', 50000) -- Cent (500 €)
local DEFAULT_SPAWN = { x = -1037.7, y = -2737.8, z = 20.2, h = 330.0 }

local Db = { }
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local NAME_PATTERN = '^[A-ZÄÖÜ][a-zäöüß\'%-]+$'

local function listCharacters(accountId)
    return Db.query([[
        SELECT c.id, c.slot, c.first_name, c.last_name, c.date_of_birth, c.gender,
               c.state, c.played_minutes, m.cash, m.bank
        FROM characters c
        LEFT JOIN character_money m ON m.character_id = c.id
        WHERE c.account_id = ? AND c.deleted_at IS NULL
        ORDER BY c.slot
    ]], { accountId })
end

-- ---------------------------------------------------------------------------
-- Client-Events (alle ohne Charakter-Pflicht — laufen VOR der Auswahl)
-- ---------------------------------------------------------------------------

HRP = HRP or {}
local Core = exports.hrp_core

local function getIdentity(src)
    return Core:GetPlayerIdentity(src)
end

RegisterNetEvent('hrp:characters:requestList', function()
    local src = source
    local ident = getIdentity(src)
    if not ident then return end
    TriggerClientEvent('hrp:characters:list', src, listCharacters(ident.accountId), MAX_SLOTS)
end)

RegisterNetEvent('hrp:characters:create', function(data)
    local src = source
    local ident = getIdentity(src)
    if not ident or ident.characterId then return end

    -- Server-seitige Validierung (Client wird nie vertraut)
    if type(data) ~= 'table' then return end
    local firstName = tostring(data.firstName or '')
    local lastName = tostring(data.lastName or '')
    local dob = tostring(data.dateOfBirth or '')
    local gender = tostring(data.gender or '')
    local backstory = tostring(data.backstory or '')

    local function fail(msg)
        TriggerClientEvent('hrp:characters:createResult', src, false, msg)
    end

    if not firstName:match(NAME_PATTERN) or #firstName > 32 then return fail('Ungültiger Vorname.') end
    if not lastName:match(NAME_PATTERN) or #lastName > 32 then return fail('Ungültiger Nachname.') end
    if not dob:match('^%d%d%d%d%-%d%d%-%d%d$') then return fail('Geburtsdatum im Format JJJJ-MM-TT angeben.') end
    local year = tonumber(dob:sub(1, 4))
    local nowYear = tonumber(os.date('%Y'))
    if not year or nowYear - year < 18 or nowYear - year > 90 then return fail('Charakter muss zwischen 18 und 90 Jahre alt sein.') end
    if gender ~= 'm' and gender ~= 'f' and gender ~= 'd' then return fail('Ungültiges Geschlecht.') end
    if #backstory < 200 then return fail('Der Lebenslauf muss mindestens 200 Zeichen umfassen.') end
    if #backstory > 10000 then return fail('Der Lebenslauf ist zu lang (max. 10.000 Zeichen).') end

    -- Freien Slot ermitteln
    local existing = listCharacters(ident.accountId)
    if #existing >= MAX_SLOTS then return fail('Alle Charakter-Slots sind belegt.') end
    local used = {}
    for _, c in ipairs(existing) do used[c.slot] = true end
    local slot
    for s = 1, MAX_SLOTS do
        if not used[s] then slot = s break end
    end

    -- Namens-Eindeutigkeit (IC-Identität)
    local dupe = Db.single(
        'SELECT id FROM characters WHERE first_name = ? AND last_name = ? AND deleted_at IS NULL',
        { firstName, lastName })
    if dupe then return fail('Dieser Name ist bereits vergeben.') end

    local correlationId = exports.hrp_logger:NewCorrelationId()

    local characterId = Db.insert([[
        INSERT INTO characters (account_id, slot, first_name, last_name, date_of_birth, gender, backstory, appearance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { ident.accountId, slot, firstName, lastName, dob, gender, backstory, json.encode(data.appearance or {}) })

    Db.insert('INSERT INTO character_vitals (character_id) VALUES (?)', { characterId })
    Db.insert('INSERT INTO character_money (character_id) VALUES (?)', { characterId })

    Core:Log(src, 'character.create', {
        target = { kind = 'character', id = tostring(characterId) },
        correlationId = correlationId,
        payload = { characterId = characterId, slot = slot, firstName = firstName,
                    lastName = lastName, dateOfBirth = dob, gender = gender },
    })

    -- Startgeld über die Geld-API (erzeugt money.create mit gleicher Korrelation)
    if STARTER_CASH > 0 then
        Core:MoneyCreate(characterId, 'cash', STARTER_CASH, 'starter.package', { correlationId = correlationId })
    end

    TriggerClientEvent('hrp:characters:createResult', src, true)
    TriggerClientEvent('hrp:characters:list', src, listCharacters(ident.accountId), MAX_SLOTS)
end)

RegisterNetEvent('hrp:characters:select', function(characterId)
    local src = source
    local ident = getIdentity(src)
    if not ident or ident.characterId then return end
    characterId = tonumber(characterId)
    if not characterId then return end

    -- Besitz-Prüfung: Charakter muss zum Account gehören
    local char = Db.single([[
        SELECT id, slot, first_name, last_name, position, state, health, armor
        FROM characters
        WHERE id = ? AND account_id = ? AND deleted_at IS NULL
    ]], { characterId, ident.accountId })
    if not char then return end
    if char.state == 'ck' then
        TriggerClientEvent('hrp:characters:createResult', src, false, 'Dieser Charakter ist permanent verstorben (CK).')
        return
    end

    Core:SetCharacter(src, char.id)

    Core:Log(src, 'session.character_select', {
        target = { kind = 'character', id = tostring(char.id) },
        payload = { characterId = char.id, slot = char.slot },
    })

    local pos = char.position and json.decode(char.position) or DEFAULT_SPAWN
    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 15000) end)
    TriggerClientEvent('hrp:characters:spawn', src, pos, {
        firstName = char.first_name,
        lastName = char.last_name,
        health = char.health,
        armor = char.armor,
    })

    Core:Log(src, 'character.spawn', {
        target = { kind = 'character', id = tostring(char.id) },
        payload = { characterId = char.id, pos = pos },
    })
end)

RegisterNetEvent('hrp:characters:delete', function(characterId)
    local src = source
    local ident = getIdentity(src)
    if not ident or ident.characterId then return end
    characterId = tonumber(characterId)
    if not characterId then return end

    local char = Db.single(
        'SELECT id, slot FROM characters WHERE id = ? AND account_id = ? AND deleted_at IS NULL',
        { characterId, ident.accountId })
    if not char then return end

    -- Soft-Delete: Daten bleiben für Nachvollziehbarkeit erhalten, Slot wird frei
    Db.update('UPDATE characters SET deleted_at = NOW(3), slot = NULL WHERE id = ?', { char.id })

    Core:Log(src, 'character.delete', {
        target = { kind = 'character', id = tostring(char.id) },
        payload = { characterId = char.id, slot = char.slot },
    })

    TriggerClientEvent('hrp:characters:list', src, listCharacters(ident.accountId), MAX_SLOTS)
end)

-- ---------------------------------------------------------------------------
-- Save-Zyklus & Disconnect-Save
-- ---------------------------------------------------------------------------

local function saveCharacter(src, ident)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local pos = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
    local health = GetEntityHealth(ped)

    Db.update([[
        UPDATE characters
        SET position = ?, health = ?, played_minutes = played_minutes + ?
        WHERE id = ?
    ]], { json.encode(pos), health, math.floor(SAVE_INTERVAL / 60000), ident.characterId })

    Core:Log(src, 'character.save', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        payload = { characterId = ident.characterId, pos = pos, health = health },
    })
end

CreateThread(function()
    while true do
        Wait(SAVE_INTERVAL)
        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = getIdentity(src)
            if ident and ident.characterId then
                saveCharacter(src, ident)
            end
        end
    end
end)

AddEventHandler('hrp:core:playerDropped', function(src, playerData)
    if playerData.characterId then
        saveCharacter(src, { characterId = playerData.characterId })
    end
end)
