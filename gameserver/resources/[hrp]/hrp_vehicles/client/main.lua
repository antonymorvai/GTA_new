-- Fahrzeug-Client: Ein-/Aussteige-Erkennung (Server validiert + loggt) und Befehle.

local wasInVehicle = false

CreateThread(function()
    while true do
        Wait(500)
        local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
        if inVehicle ~= wasInVehicle then
            wasInVehicle = inVehicle
            TriggerServerEvent('hrp:vehicles:seat', inVehicle)
        end
    end
end)

RegisterCommand('buycar', function(_, args)
    if not args[1] then
        TriggerEvent('chat:addMessage', { args = { '^1FAHRZEUG', 'Nutzung: /buycar <modell>' } })
        return
    end
    TriggerServerEvent('hrp:vehicles:buy', args[1]:lower())
end, false)

RegisterCommand('garage', function(_, args)
    if not args[1] then
        TriggerEvent('chat:addMessage', { args = { '^1FAHRZEUG', 'Nutzung: /garage <kennzeichen>' } })
        return
    end
    TriggerServerEvent('hrp:vehicles:garageOut', table.concat(args, ' '):upper():sub(1, 8))
end, false)

RegisterCommand('park', function()
    TriggerServerEvent('hrp:vehicles:garageIn')
end, false)

RegisterCommand('givekey', function(_, args)
    local target = tonumber(args[1])
    if not target or not args[2] then
        TriggerEvent('chat:addMessage', { args = { '^1FAHRZEUG', 'Nutzung: /givekey <spielerId> <kennzeichen>' } })
        return
    end
    TriggerServerEvent('hrp:vehicles:giveKey', target, table.concat(args, ' ', 2):upper():sub(1, 8))
end, false)

RegisterCommand('refuel', function()
    TriggerServerEvent('hrp:vehicles:refuel')
end, false)

RegisterCommand('trunk', function() TriggerServerEvent('hrp:vehicles:trunk', 'list') end, false)
RegisterCommand('trunkstore', function(_, args)
    if args[1] then TriggerServerEvent('hrp:vehicles:trunk', 'store', args[1]) end
end, false)
RegisterCommand('trunktake', function(_, args)
    if args[1] then TriggerServerEvent('hrp:vehicles:trunk', 'take', args[1]) end
end, false)
RegisterCommand('myvehicles', function()
    TriggerServerEvent('hrp:vehicles:list')
end, false)
