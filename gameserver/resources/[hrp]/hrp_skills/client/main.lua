-- Ausdauer-Skill: Sprint-Sekunden werden gebatcht gemeldet (Server vergibt XP
-- und meldet das Level zurück — hohes Level regeneriert Ausdauer schneller).

local staminaLevel = 0

RegisterNetEvent('hrp:skills:staminaLevel', function(level)
    staminaLevel = level or 0
end)

CreateThread(function()
    local sprintSeconds = 0
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedSprinting(ped) then
            sprintSeconds = sprintSeconds + 1
        end
        if sprintSeconds >= 30 then
            TriggerServerEvent('hrp:skills:sprint', sprintSeconds)
            sprintSeconds = 0
        end
        -- Trainierte Ausdauer: ab Level 5 regeneriert der Sprint-Balken schneller
        if staminaLevel >= 5 and not IsPedSprinting(ped) then
            RestorePlayerStamina(PlayerId(), 0.2 + staminaLevel * 0.02)
        end
    end
end)
