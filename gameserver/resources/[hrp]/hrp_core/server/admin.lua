--[[
    Admin-Basis-Befehle (in-game) — RBAC-geprüft, JEDE Nutzung erzeugt admin.action.
    Umfangreiche Admin-Tools folgen mit dem ACP (Phase 5); dies ist das
    Minimum für Betrieb & Tests in Phase 1.
]]

local function logAdminAction(src, action, args, permission, targetSrc)
    local target = targetSrc and HRP.Players[targetSrc] or nil
    HRP.Log(src, 'admin.action', {
        target = target and { kind = 'account', id = tostring(target.accountId) } or nil,
        payload = {
            action = action,
            targetAccountId = target and target.accountId or nil,
            targetCharacterId = target and target.characterId or nil,
            args = args,
            permission = permission,
        },
    })
end

--- Registriert einen Admin-Command mit RBAC-Pflicht + Audit-Log.
local function registerAdminCommand(name, permission, handler)
    RegisterCommand(name, function(src, args)
        if src == 0 then
            handler(0, args) -- Server-Konsole darf immer (physischer Zugriff)
            return
        end
        if not HRP.HasPermission(src, permission) then
            HRP.Log(src, 'security.invalid_event', {
                payload = { eventName = 'command:' .. name, violation = 'permission:' .. permission },
            })
            TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Keine Berechtigung.' } })
            return
        end
        logAdminAction(src, name, args, permission, tonumber(args[1]))
        handler(src, args)
    end, true)
end

-- /goto <serverId>
registerAdminCommand('goto', 'game.admin.teleport', function(src, args)
    if src == 0 then return end
    local target = tonumber(args[1])
    if not target or not HRP.Players[target] then return end
    SetEntityCoords(GetPlayerPed(src), GetEntityCoords(GetPlayerPed(target)))
end)

-- /givemoney <serverId> <cash|bank> <betragInCent>
registerAdminCommand('givemoney', 'game.admin.money_set', function(src, args)
    local target, account, amount = tonumber(args[1]), args[2], tonumber(args[3])
    if not target or not HRP.Players[target] or not HRP.Players[target].characterId then return end
    if account ~= 'cash' and account ~= 'bank' then return end
    if not amount or amount <= 0 then return end
    local adminAccount = src ~= 0 and HRP.Players[src].accountId or nil
    HRP.Money.Create(HRP.Players[target].characterId, account, math.floor(amount), 'admin.grant',
        { adminAccountId = adminAccount })
end)

-- /kick <serverId> <grund...>
registerAdminCommand('kick', 'game.admin.kick', function(src, args)
    local target = tonumber(args[1])
    if not target or not HRP.Players[target] then return end
    local reason = table.concat(args, ' ', 2)
    DropPlayer(target, 'Gekickt: ' .. (reason ~= '' and reason or 'Kein Grund angegeben'))
end)

-- /ban <serverId> <stunden|0=permanent> <grund...>
registerAdminCommand('ban', 'game.admin.ban', function(src, args)
    local target, hours = tonumber(args[1]), tonumber(args[2])
    if not target or not HRP.Players[target] or not hours then return end
    local reason = table.concat(args, ' ', 3)
    if reason == '' then reason = 'Kein Grund angegeben' end
    local targetAccount = HRP.Players[target].accountId
    local adminAccount = src ~= 0 and HRP.Players[src].accountId or nil

    local banId = Db.insert([[
        INSERT INTO account_bans (account_id, issued_by, reason, expires_at)
        VALUES (?, ?, ?, IF(? = 0, NULL, DATE_ADD(NOW(3), INTERVAL ? HOUR)))
    ]], { targetAccount, adminAccount, reason, hours, hours })

    HRP.Log(src ~= 0 and src or nil, 'security.ban', {
        target = { kind = 'account', id = tostring(targetAccount) },
        payload = { banId = banId, reason = reason,
                    expiresAt = hours > 0 and (os.time() + hours * 3600) * 1000 or nil,
                    byAccountId = adminAccount },
    })
    DropPlayer(target, 'Du wurdest gebannt: ' .. reason)
end)
