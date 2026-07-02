--[[
    hrp_core – zentrales Framework-Objekt & Spieler-Registry.

    HRP.Players[src] = {
        accountId, sessionId, ip,
        characterId (nil bis Charakterwahl),
        permissions (Set), roles (Liste),
    }
]]

HRP = {
    Players = {},
    ServerId = GetConvar('hrp_server_id', 'main'),
}

--- Log-Shortcut: reichert actor automatisch aus der Registry an.
function HRP.Log(src, eventType, data)
    data = data or {}
    if src and src > 0 then
        local p = HRP.Players[src]
        if p then
            data.actor = data.actor or {
                accountId = p.accountId,
                characterId = p.characterId,
                sessionId = p.sessionId,
            }
        end
        if not data.pos then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local c = GetEntityCoords(ped)
                data.pos = { x = c.x, y = c.y, z = c.z }
            end
        end
    end
    exports.hrp_logger:Log(eventType, data)
end

--- Identität eines verbundenen Spielers (für andere Ressourcen, z. B. Position-Sampler).
function HRP.GetPlayerIdentity(src)
    local p = HRP.Players[src]
    if not p then return nil end
    return {
        accountId = p.accountId,
        characterId = p.characterId,
        sessionId = p.sessionId,
    }
end

--- Charakterwechsel durch hrp_characters gemeldet.
function HRP.SetCharacter(src, characterId)
    local p = HRP.Players[src]
    if not p then return false end
    p.characterId = characterId
    Db.update('UPDATE sessions SET character_id = ? WHERE id = ?', { characterId, p.sessionId })
    return true
end

exports('GetPlayerIdentity', HRP.GetPlayerIdentity)
exports('IsValidReason', function(category, code) return HRPReasons.IsValid(category, code) end)
exports('SetCharacter', function(src, characterId) return HRP.SetCharacter(src, characterId) end)
exports('Log', function(src, eventType, data) HRP.Log(src, eventType, data) end)
