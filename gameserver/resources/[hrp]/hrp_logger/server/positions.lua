--[[
    Position-Sampler: sammelt alle N Sekunden (Convar hrp_position_interval,
    Standard 5000 ms) die Positionen aller aktiven Charaktere und loggt sie als
    EIN position.batch-Event -> Bewegungs-Replay im ACP.

    Die Zuordnung src -> {characterId, sessionId} liefert hrp_core.
]]

local interval = GetConvarInt('hrp_position_interval', 5000)

CreateThread(function()
    while true do
        Wait(interval)

        local samples = {}
        for _, src in ipairs(GetPlayers()) do
            local srcNum = tonumber(src)
            local ok, ident = pcall(function()
                return exports.hrp_core:GetPlayerIdentity(srcNum)
            end)
            if not ok then ident = nil end
            if ident and ident.characterId then
                local ped = GetPlayerPed(srcNum)
                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    samples[#samples + 1] = {
                        characterId = ident.characterId,
                        sessionId = ident.sessionId,
                        x = coords.x, y = coords.y, z = coords.z,
                        heading = GetEntityHeading(ped),
                        speed = GetEntitySpeed(ped),
                    }
                end
            end
        end

        if #samples > 0 then
            Log('position.batch', { payload = { samples = samples } })
        end
    end
end)
