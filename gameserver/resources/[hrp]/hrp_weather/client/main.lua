--[[
    Wetter/Zeit-Client: wendet Server-Zustand an. Bei Regen (State Bag
    'hrp:wet') greift reduzierte Reifenhaftung — Glätte ist spürbar.
]]

local targetHour, targetMinute = 9, 0

RegisterNetEvent('hrp:weather:set', function(weather, transitionSec)
    SetWeatherTypeOvertimePersist(weather, transitionSec + 0.0)
end)

RegisterNetEvent('hrp:weather:time', function(hour, minute)
    targetHour, targetMinute = hour, minute
end)

CreateThread(function()
    while true do
        Wait(1000)
        NetworkOverrideClockTime(targetHour, targetMinute, 0)
    end
end)

-- Nasse Fahrbahn: Grip reduzieren, solange die Regenfront aktiv ist
CreateThread(function()
    while true do
        Wait(2000)
        local wet = GlobalState['hrp:wet'] == true
        local ped = PlayerPedId()
        if wet and IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                SetVehicleReduceGrip(veh, true)
            end
        elseif IsPedInAnyVehicle(ped, false) then
            SetVehicleReduceGrip(GetVehiclePedIsIn(ped, false), false)
        end
    end
end)
