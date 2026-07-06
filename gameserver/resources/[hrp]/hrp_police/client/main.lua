-- Polizei-Client: Handschellen-Zustand (Anim + Bewegungssperre).

local isCuffed = false

RegisterNetEvent('hrp:police:cuffed', function(state)
    isCuffed = state
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        TriggerEvent('chat:addMessage', { args = { '^1POLIZEI', 'Dir wurden Handschellen angelegt.' } })
        CreateThread(function()
            while isCuffed do
                Wait(0)
                local p = PlayerPedId()
                DisableControlAction(0, 24, true)   -- Angriff
                DisableControlAction(0, 25, true)   -- Zielen
                DisableControlAction(0, 21, true)   -- Sprint
                DisableControlAction(0, 22, true)   -- Springen
                DisableControlAction(0, 44, true)   -- Deckung
                DisableControlAction(0, 75, true)   -- Fahrzeug verlassen
                if not IsEntityPlayingAnim(p, 'mp_arresting', 'idle', 3) then
                    TaskPlayAnim(p, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
        end)
    else
        ClearPedTasks(ped)
    end
end)
