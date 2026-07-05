--[[
    Client-Anfragen (abgesichert über hrp_core-Security) + Admin-Command.
    Volles Inventar-UI folgt in Phase 2 — hier die server-autoritative Basis.
]]

local Core = exports.hrp_core

-- Item an nahestehenden Spieler übergeben
-- (Secure-Event-Registrierung läuft über hrp_core-Export, da HRP dort lebt)
Core:RegisterSecureEvent('hrp:inventory:give', {
    rate = 1, burst = 3,
    schema = {
        { type = 'number', integer = true, min = 1 },                    -- targetServerId
        { type = 'string', maxLen = 36, pattern = '^[%x%-]+$' },         -- item uuid
    },
}, function(src, targetSrc, uuid)
    local giver = Core:GetPlayerIdentity(src)
    local receiver = Core:GetPlayerIdentity(targetSrc)
    if not receiver or not receiver.characterId then return end

    local p1, p2 = GetEntityCoords(GetPlayerPed(src)), GetEntityCoords(GetPlayerPed(targetSrc))
    if #(p1 - p2) > 3.0 then
        Core:Log(src, 'security.invalid_event', {
            payload = { eventName = 'hrp:inventory:give', violation = 'distance' },
        })
        return
    end

    local ok, err = Inventory.Transfer(uuid, giver.characterId, receiver.characterId, { srcForLog = src })
    TriggerClientEvent('chat:addMessage', src, {
        args = { ok and '^2INVENTAR' or '^1INVENTAR', ok and 'Item übergeben.' or ('Fehlgeschlagen: ' .. tostring(err)) },
    })
end)

-- Item auf den Boden legen
Core:RegisterSecureEvent('hrp:inventory:drop', {
    rate = 2, burst = 5,
    schema = { { type = 'string', maxLen = 36, pattern = '^[%x%-]+$' } },
}, function(src, uuid)
    local ident = Core:GetPlayerIdentity(src)
    local inst = Inventory.GetContainer('character', ident.characterId)
    local owned = false
    for _, it in ipairs(inst or {}) do
        if it.uuid == uuid then owned = true break end
    end
    if not owned then return end

    local c = GetEntityCoords(GetPlayerPed(src))
    local groundId = ('%.1f:%.1f:%.1f'):format(c.x, c.y, c.z)
    Inventory.Move(uuid, { type = 'ground', id = groundId }, { srcForLog = src })
end)

-- Inventar-Inhalt fürs NUI (eigener Charakter)
Core:RegisterSecureEvent('hrp:inventory:request', { rate = 1, burst = 4 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local items = Inventory.GetContainer('character', ident.characterId) or {}
    local weight = Inventory.GetCarryWeight(ident.characterId) or 0
    TriggerClientEvent('hrp:inventory:contents', src, items, weight,
        GetConvarInt('hrp_max_carry_grams', 30000))
end)

-- Item benutzen: konsumiert 1 Einheit und meldet die Nutzung an Effekt-Module
-- (z. B. hrp_medical für Essen/Trinken/Verbände) über das Server-Event
-- 'hrp:items:used' (src, itemName, uuid).
Core:RegisterSecureEvent('hrp:inventory:use', {
    rate = 1, burst = 3,
    schema = { { type = 'string', maxLen = 36, pattern = '^[%x%-]+$' } },
}, function(src, uuid)
    local ident = Core:GetPlayerIdentity(src)
    local instance
    for _, it in ipairs(Inventory.GetContainer('character', ident.characterId) or {}) do
        if it.uuid == uuid then instance = it break end
    end
    if not instance then return end

    local def = Inventory.GetDefinition(instance.name)
    if not def or def.usable ~= 1 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1INVENTAR', 'Dieses Item ist nicht benutzbar.' } })
        return
    end

    local ok = Inventory.Consume(uuid, 1, { srcForLog = src })
    if ok then
        TriggerEvent('hrp:items:used', src, instance.name, uuid)
    end
end)

-- /giveitem <serverId> <itemName> <menge> — Admin, RBAC-geprüft + doppelt geloggt
RegisterCommand('giveitem', function(src, args)
    if src ~= 0 and not Core:HasPermission(src, 'game.admin.item_give') then
        if src ~= 0 then
            Core:Log(src, 'security.invalid_event', {
                payload = { eventName = 'command:giveitem', violation = 'permission:game.admin.item_give' },
            })
        end
        return
    end

    local targetSrc, itemName, qty = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    if not targetSrc or not itemName then
        print('Usage: giveitem <serverId> <itemName> [menge]')
        return
    end
    local target = Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return end

    if src ~= 0 then
        local admin = Core:GetPlayerIdentity(src)
        Core:Log(src, 'admin.action', {
            target = { kind = 'account', id = tostring(target.accountId) },
            payload = { action = 'giveitem', targetAccountId = target.accountId,
                        targetCharacterId = target.characterId,
                        args = { itemName, qty }, permission = 'game.admin.item_give' },
        })
    end

    local uuid, err = Inventory.Create(itemName, qty, 'admin.give',
        { type = 'character', id = target.characterId },
        { createdBy = nil, srcForLog = src ~= 0 and src or nil })
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, {
            args = { uuid and '^2ADMIN' or '^1ADMIN', uuid and ('Item erstellt: ' .. uuid) or ('Fehler: ' .. tostring(err)) },
        })
    else
        print(uuid and ('OK: ' .. uuid) or ('Fehler: ' .. tostring(err)))
    end
end, true)
