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
RegisterCommand('givehousekey', function(_, args)
    local target = tonumber(args[1])
    if not target then
        TriggerEvent('chat:addMessage', { args = { '^1IMMOBILIE', 'Nutzung: /givehousekey <spielerId>' } })
        return
    end
    TriggerServerEvent('hrp:properties:giveKey', target)
end, false)
