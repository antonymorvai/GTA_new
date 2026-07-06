--[[
    HUD-Client (2.0): sammelt lokale Werte (HP, Rüstung, Speed, Mikrofon) und
    server-gepushte Werte (Vitals via hrp_medical, Tank via hrp_vehicles,
    Statuseffekte). Ringe blenden kontextuell aus, wenn alles ok ist —
    Vollbild-Immersion. Rein darstellend, keine Spiellogik.
]]

local vitals = { hunger = 100, thirst = 100, stress = 0 }
local fuel = nil
local clock = { h = 9, m = 0 }
local status = {}   -- status[name] = true (verletzt/müde/high/überladen/gesucht ...)

RegisterNetEvent('hrp:weather:time', function(hour, minute)
    clock.h, clock.m = hour, minute
end)

RegisterNetEvent('hrp:medical:vitals', function(hunger, thirst, stress)
    vitals.hunger = hunger
    vitals.thirst = thirst
    if stress ~= nil then vitals.stress = stress end
end)

RegisterNetEvent('hrp:vehicles:fuel', function(liters, tank)
    fuel = { liters = liters, tank = tank }
end)

-- Statuseffekte an-/abschalten (von beliebigen Modulen)
RegisterNetEvent('hrp:hud:status', function(name, active)
    status[name] = active or nil
end)

RegisterNetEvent('hrp:characters:spawn', function()
    CreateThread(function()
        Wait(2000)
        TriggerServerEvent('hrp:medical:requestVitals')
    end)
end)

-- lokale Statusquellen (Client kennt sie ohne Server)
RegisterNetEvent('hrp:medical:bleeding', function(active) status.bleeding = active or nil end)
RegisterNetEvent('hrp:inventory:overweight', function(heavy) status.overweight = heavy or nil end)

CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        if not inVehicle then fuel = nil end

        local speed = 0
        if inVehicle then
            speed = math.floor(GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 3.6)
        end

        -- Statusliste zusammensetzen
        local icons = {}
        if status.bleeding then icons[#icons + 1] = 'bleeding' end
        if status.overweight then icons[#icons + 1] = 'overweight' end
        if status.injured then icons[#icons + 1] = 'injured' end
        if status.high then icons[#icons + 1] = 'high' end
        if vitals.stress and vitals.stress >= 70 then icons[#icons + 1] = 'stress' end
        if IsPedRunning(ped) and GetPlayerStamina and false then end   -- Platzhalter
        local talking = NetworkIsPlayerTalking(PlayerId())
        if talking then icons[#icons + 1] = 'talking' end

        SendNUIMessage({
            action = 'update',
            health = math.max(0, math.floor((GetEntityHealth(ped) - 100) / 100 * 100)),
            armor = GetPedArmour(ped),
            hunger = vitals.hunger,
            thirst = vitals.thirst,
            stress = vitals.stress or 0,
            speed = inVehicle and speed or nil,
            fuel = fuel and math.floor(fuel.liters / fuel.tank * 100) or nil,
            clock = ('%02d:%02d'):format(clock.h, clock.m),
            status = icons,
            voice = talking,
        })
    end
end)
