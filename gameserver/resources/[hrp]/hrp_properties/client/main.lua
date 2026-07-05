-- Immobilien-Client: Teleport-Umsetzung + Befehle. Zugang prüft der Server.

RegisterNetEvent('hrp:properties:teleport', function(pos)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(400)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.h or 0.0)
    Wait(300)
    DoScreenFadeIn(500)
end)

RegisterCommand('buyhouse', function() TriggerServerEvent('hrp:properties:buy') end, false)
RegisterCommand('enterhouse', function() TriggerServerEvent('hrp:properties:enter') end, false)
RegisterCommand('leavehouse', function() TriggerServerEvent('hrp:properties:leave') end, false)
RegisterCommand('lockpickdoor', function() TriggerServerEvent('hrp:properties:lockpick') end, false)
RegisterCommand('homestorage', function() TriggerServerEvent('hrp:properties:storage', 'list') end, false)
RegisterCommand('homestore', function(_, args)
    if args[1] then TriggerServerEvent('hrp:properties:storage', 'store', args[1]) end
end, false)
RegisterCommand('hometake', function(_, args)
    if args[1] then TriggerServerEvent('hrp:properties:storage', 'take', args[1]) end
end, false)
RegisterCommand('givehousekey', function(_, args)
    local target = tonumber(args[1])
    if not target then
        TriggerEvent('chat:addMessage', { args = { '^1IMMOBILIE', 'Nutzung: /givehousekey <spielerId>' } })
        return
    end
    TriggerServerEvent('hrp:properties:giveKey', target)
end, false)
