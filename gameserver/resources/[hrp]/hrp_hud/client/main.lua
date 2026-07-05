--[[
    HUD-Client: sammelt lokale Werte (HP, Rüstung, Geschwindigkeit) und
    server-gepushte Werte (Hunger/Durst via hrp_medical, Tank via hrp_vehicles)
    und rendert sie im NUI. Rein darstellend — keine Spiellogik.
]]

local vitals = { hunger = 100, thirst = 100 }
local fuel = nil   -- {liters, tank} nur im Fahrzeug
local clock = { h = 9, m = 0 }

RegisterNetEvent('hrp:weather:time', function(hour, minute)
    clock.h, clock.m = hour, minute
end)

RegisterNetEvent('hrp:medical:vitals', function(hunger, thirst)
    vitals.hunger = hunger
    vitals.thirst = thirst
end)

RegisterNetEvent('hrp:vehicles:fuel', function(liters, tank)
    fuel = { liters = liters, tank = tank }
end)

-- Vitals nach Spawn anfragen (Charakterwahl abgeschlossen)
RegisterNetEvent('hrp:characters:spawn', function()
    CreateThread(function()
        Wait(2000)
        TriggerServerEvent('hrp:medical:requestVitals')
    end)
end)

CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        if not inVehicle then fuel = nil end

        local speed = 0
        if inVehicle then
            speed = math.floor(GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 3.6)
        end

        SendNUIMessage({
            action = 'update',
            health = math.max(0, GetEntityHealth(ped) - 100),  -- 0..100 normalisiert
            armor = GetPedArmour(ped),
            hunger = vitals.hunger,
            thirst = vitals.thirst,
            speed = inVehicle and speed or nil,
            fuel = fuel and math.floor(fuel.liters / fuel.tank * 100) or nil,
            clock = ('%02d:%02d'):format(clock.h, clock.m),
        })
    end
end)
