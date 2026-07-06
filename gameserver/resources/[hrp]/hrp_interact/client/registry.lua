--[[
    Standard-Interaktionen: verdrahtet die häufigsten Aktionen aus anderen
    Modulen ins Interact-System. Läuft nach dem Start aller Ressourcen.
    (Zonen-Koordinaten spiegeln die Server-seitigen Orte der jeweiligen Module.)
]]

CreateThread(function()
    Wait(2000)

    -- Tankstellen: Tanken per Blick aufs Fahrzeug an der Station wäre doppelt —
    -- daher als Fahrzeug-Option (Server prüft Station + Bestand ohnehin).
    Interact.AddVehicleOption('refuel', 'Tanken', {
        { label = '⛽ Tanken', event = 'hrp:vehicles:refuel', server = true },
        { label = '🧰 Kofferraum', event = 'hrp:interact:trunkList', server = false,
          action = function() TriggerServerEvent('hrp:vehicles:trunk', 'list') end },
    }, function() return true end)

    -- Bank-/ATM-Standorte (Spiegel von hrp_banking LOCATIONS)
    local banks = {
        vector3(150.2, -1040.5, 29.4), vector3(-1212.9, -330.9, 37.8),
        vector3(-2962.6, 482.9, 15.7), vector3(1175.0, 2706.6, 38.1),
        vector3(-112.2, 6469.3, 31.6),
    }
    for i, pos in ipairs(banks) do
        Interact.AddZone('bank_' .. i, pos, 2.5, 'Bank', {
            { label = '💳 Kontostand', action = function() TriggerServerEvent('hrp:banking:balance') end },
            { label = '💰 Einzahlen', action = function()
                TriggerEvent('hrp:interact:promptAmount', 'deposit') end },
            { label = '🏧 Abheben', action = function()
                TriggerEvent('hrp:interact:promptAmount', 'withdraw') end },
        })
    end

    -- Garagen (Spiegel von hrp_vehicles GARAGES)
    local garages = {
        { pos = vector3(215.9, -810.1, 30.7), name = 'legion' },
        { pos = vector3(-112.0, 6425.9, 31.4), name = 'paleto' },
    }
    for _, g in ipairs(garages) do
        Interact.AddZone('garage_' .. g.name, g.pos, 4.0, 'Garage', {
            { label = '🚗 Fahrzeuge', action = function() TriggerServerEvent('hrp:vehicles:list') end },
            { label = '🅿 Einparken', action = function() TriggerServerEvent('hrp:vehicles:garageIn') end },
        })
    end
end)

-- Kleiner Betrags-Dialog (Fallback über Chat-Prompt bleibt bestehen)
RegisterNetEvent('hrp:interact:promptAmount', function(kind)
    SendNUIMessage({ action = 'amount', kind = kind })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('amount', function(data, cb)
    SetNuiFocus(false, false)
    local amount = tonumber(data.amount)
    if amount and amount > 0 then
        local cents = math.floor(amount * 100)
        if data.kind == 'deposit' then TriggerServerEvent('hrp:banking:deposit', cents)
        elseif data.kind == 'withdraw' then TriggerServerEvent('hrp:banking:withdraw', cents) end
    end
    cb({})
end)
