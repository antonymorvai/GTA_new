--[[
    RBAC: Rollen/Permissions aus der DB, gecacht pro Spieler-Session.
    Jede Grant/Revoke-Operation erzeugt ein rbac.*-Event.
]]

local function loadPermissions(accountId)
    local rows = Db.query([[
        SELECT DISTINCT p.name
        FROM account_roles ar
        JOIN role_permissions rp ON rp.role_id = ar.role_id
        JOIN permissions p ON p.id = rp.permission_id
        WHERE ar.account_id = ?
    ]], { accountId })
    local set = {}
    for _, row in ipairs(rows or {}) do set[row.name] = true end
    return set
end

function HRP.HasPermission(src, permission)
    local p = HRP.Players[src]
    if not p then return false end
    if not p.permissions then
        p.permissions = loadPermissions(p.accountId)
    end
    return p.permissions[permission] == true
end

--- Cache invalidieren (z. B. nach Rollenänderung im ACP)
function HRP.ReloadPermissions(src)
    local p = HRP.Players[src]
    if p then p.permissions = nil end
end

--- Rolle vergeben (nur server-seitig aufrufbar, z. B. via ACP-Bridge/Console).
function HRP.GrantRole(accountId, roleName, byAccountId)
    local roleId = Db.scalar('SELECT id FROM roles WHERE name = ?', { roleName })
    if not roleId then return false, 'unknown_role' end
    Db.update([[
        INSERT IGNORE INTO account_roles (account_id, role_id, granted_by) VALUES (?, ?, ?)
    ]], { accountId, roleId, byAccountId })
    exports.hrp_logger:Log('rbac.role_grant', {
        actor = byAccountId and { accountId = byAccountId } or nil,
        target = { kind = 'account', id = tostring(accountId) },
        payload = { accountId = accountId, role = roleName, byAccountId = byAccountId },
    })
    -- Online-Spieler: Cache invalidieren
    for src, p in pairs(HRP.Players) do
        if p.accountId == accountId then p.permissions = nil end
    end
    return true
end

function HRP.RevokeRole(accountId, roleName, byAccountId)
    local roleId = Db.scalar('SELECT id FROM roles WHERE name = ?', { roleName })
    if not roleId then return false, 'unknown_role' end
    Db.update('DELETE FROM account_roles WHERE account_id = ? AND role_id = ?', { accountId, roleId })
    exports.hrp_logger:Log('rbac.role_revoke', {
        actor = byAccountId and { accountId = byAccountId } or nil,
        target = { kind = 'account', id = tostring(accountId) },
        payload = { accountId = accountId, role = roleName, byAccountId = byAccountId },
    })
    for src, p in pairs(HRP.Players) do
        if p.accountId == accountId then p.permissions = nil end
    end
    return true
end

exports('HasPermission', function(src, permission) return HRP.HasPermission(src, permission) end)
exports('GrantRole', function(...) return HRP.GrantRole(...) end)
exports('RevokeRole', function(...) return HRP.RevokeRole(...) end)

-- Konsolen-Befehle für Bootstrap (txAdmin-Konsole; src 0 = Konsole)
RegisterCommand('hrp_grantrole', function(src, args)
    if src ~= 0 then return end -- nur Server-Konsole
    local accountId, role = tonumber(args[1]), args[2]
    if not accountId or not role then
        print('Usage: hrp_grantrole <accountId> <role>')
        return
    end
    local ok, err = HRP.GrantRole(accountId, role, nil)
    print(ok and 'OK' or ('Fehler: ' .. err))
end, true)
