--[[
    hrp_phone – Smartphone-Basis: Rufnummer pro Charakter (lazy vergeben),
    Kontakte, SMS. Voraussetzung: Der Charakter trägt ein 'phone'-Item
    (Handys sind stehlbar; IMEI-/Ortungs-Features folgen mit der Voice-Phase).

    Logging: comms.sms mit Inhalt (Katalog §comms — SMS voll, Anrufe später
    nur Metadaten; Inhalte nur mit richterlichem In-RP-Beschluss).
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local Core = exports.hrp_core
local Inv = exports.hrp_inventory

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2HANDY' or '^1HANDY', msg } })
end

local function hasPhone(characterId)
    for _, it in ipairs(Inv:GetContainer('character', characterId) or {}) do
        if it.name == 'phone' then return true end
    end
    return false
end

local function getNumber(characterId)
    local existing = Db.scalar('SELECT number FROM phone_numbers WHERE character_id = ?', { characterId })
    if existing then return existing end
    for _ = 1, 20 do
        local number = ('555%04d'):format(math.random(0, 9999))
        if not Db.scalar('SELECT 1 FROM phone_numbers WHERE number = ?', { number }) then
            Db.insert('INSERT INTO phone_numbers (character_id, number) VALUES (?, ?)', { characterId, number })
            return number
        end
    end
    return nil
end

exports('GetNumber', getNumber)

local function findSrcByNumber(number)
    local characterId = Db.scalar('SELECT character_id FROM phone_numbers WHERE number = ?', { number })
    if not characterId then return nil, nil end
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local ident = Core:GetPlayerIdentity(src)
        if ident and ident.characterId == characterId then return src, characterId end
    end
    return nil, characterId
end

Core:RegisterSecureEvent('hrp:phone:myNumber', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    if not hasPhone(ident.characterId) then return reply(src, false, 'Du hast kein Handy.') end
    reply(src, true, 'Deine Nummer: ' .. (getNumber(ident.characterId) or 'Fehler'))
end)

Core:RegisterSecureEvent('hrp:phone:sms', {
    rate = 0.5, burst = 3,
    schema = {
        { type = 'string', maxLen = 7, pattern = '^%d%d%d%d%d%d%d$' },
        { type = 'string', maxLen = 500 },
    },
}, function(src, toNumber, body)
    local ident = Core:GetPlayerIdentity(src)
    if not hasPhone(ident.characterId) then return reply(src, false, 'Du hast kein Handy.') end
    if #body < 1 then return end

    local fromNumber = getNumber(ident.characterId)
    if not fromNumber then return reply(src, false, 'Keine Rufnummer.') end

    local targetSrc, targetCharacterId = findSrcByNumber(toNumber)
    if not targetCharacterId then return reply(src, false, 'Diese Nummer ist nicht vergeben.') end

    Db.insert('INSERT INTO phone_messages (from_number, to_number, body) VALUES (?, ?, ?)',
        { fromNumber, toNumber, body })

    Core:Log(src, 'comms.sms', {
        target = { kind = 'character', id = tostring(targetCharacterId) },
        payload = { fromNumber = fromNumber, toNumber = toNumber, body = body },
    })

    reply(src, true, ('SMS an %s gesendet.'):format(toNumber))
    if targetSrc and hasPhone(targetCharacterId) then
        TriggerClientEvent('chat:addMessage', targetSrc, {
            args = { '^3SMS von ' .. fromNumber, body },
        })
    end
end)

Core:RegisterSecureEvent('hrp:phone:addContact', {
    rate = 1, burst = 3,
    schema = {
        { type = 'string', maxLen = 64 },
        { type = 'string', maxLen = 7, pattern = '^%d%d%d%d%d%d%d$' },
    },
}, function(src, name, number)
    local ident = Core:GetPlayerIdentity(src)
    if not hasPhone(ident.characterId) then return reply(src, false, 'Du hast kein Handy.') end
    Db.update([[
        INSERT INTO phone_contacts (character_id, name, number) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { ident.characterId, name, number })
    reply(src, true, ('Kontakt gespeichert: %s (%s)'):format(name, number))
end)

Core:RegisterSecureEvent('hrp:phone:contacts', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    if not hasPhone(ident.characterId) then return reply(src, false, 'Du hast kein Handy.') end
    local rows = Db.query('SELECT name, number FROM phone_contacts WHERE character_id = ? ORDER BY name', { ident.characterId }) or {}
    if #rows == 0 then return reply(src, true, 'Keine Kontakte gespeichert.') end
    for _, c in ipairs(rows) do
        reply(src, true, ('%s: %s'):format(c.name, c.number))
    end
end)
