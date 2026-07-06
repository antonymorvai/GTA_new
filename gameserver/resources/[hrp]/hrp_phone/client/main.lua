-- Smartphone: NUI (F1 oder /phone) + Befehls-Fallbacks.

local phoneOpen = false

local function closePhone()
    phoneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

RegisterCommand('phone', function()
    if phoneOpen then return closePhone() end
    phoneOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
    TriggerServerEvent('hrp:phone:data')
end, false)

RegisterKeyMapping('phone', 'Smartphone öffnen', 'keyboard', 'F1')

RegisterNetEvent('hrp:phone:dataResult', function(data)
    if phoneOpen then SendNUIMessage({ action = 'data', data = data }) end
end)

RegisterNetEvent('hrp:phone:noPhone', function()
    closePhone()
    TriggerEvent('chat:addMessage', { args = { '^1HANDY', 'Du hast kein Handy dabei.' } })
end)

RegisterNUICallback('close', function(_, cb) closePhone() cb({}) end)
RegisterNUICallback('refresh', function(_, cb) TriggerServerEvent('hrp:phone:data') cb({}) end)
RegisterNUICallback('sms', function(d, cb)
    TriggerServerEvent('hrp:phone:sms', d.number, d.body)
    Wait(300) TriggerServerEvent('hrp:phone:data') cb({})
end)
RegisterNUICallback('tweet', function(d, cb)
    TriggerServerEvent('hrp:phone:tweet', d.body)
    Wait(300) TriggerServerEvent('hrp:phone:data') cb({})
end)
RegisterNUICallback('ad', function(d, cb)
    TriggerServerEvent('hrp:phone:ad', d.body)
    Wait(300) TriggerServerEvent('hrp:phone:data') cb({})
end)
RegisterNUICallback('addContact', function(d, cb)
    TriggerServerEvent('hrp:phone:addContact', d.name, d.number)
    Wait(300) TriggerServerEvent('hrp:phone:data') cb({})
end)

-- Smartphone-Befehle (Basis; Fallback ohne NUI).

RegisterCommand('mynumber', function()
    TriggerServerEvent('hrp:phone:myNumber')
end, false)

RegisterCommand('sms', function(_, args)
    local number = args[1]
    local body = table.concat(args, ' ', 2)
    if not number or body == '' then
        TriggerEvent('chat:addMessage', { args = { '^1HANDY', 'Nutzung: /sms <nummer> <text>' } })
        return
    end
    TriggerServerEvent('hrp:phone:sms', number, body)
end, false)

RegisterCommand('addcontact', function(_, args)
    local name, number = args[1], args[2]
    if not name or not number then
        TriggerEvent('chat:addMessage', { args = { '^1HANDY', 'Nutzung: /addcontact <name> <nummer>' } })
        return
    end
    TriggerServerEvent('hrp:phone:addContact', name, number)
end, false)

RegisterCommand('contacts', function()
    TriggerServerEvent('hrp:phone:contacts')
end, false)

RegisterCommand('tweet', function(_, args)
    local body = table.concat(args, ' ')
    if body == '' then
        TriggerEvent('chat:addMessage', { args = { '^1HANDY', 'Nutzung: /tweet <text>' } })
        return
    end
    TriggerServerEvent('hrp:phone:tweet', body)
end, false)

RegisterCommand('tweets', function() TriggerServerEvent('hrp:phone:tweets') end, false)

RegisterCommand('anzeige', function(_, args)
    local body = table.concat(args, ' ')
    if body == '' then
        TriggerEvent('chat:addMessage', { args = { '^1HANDY', 'Nutzung: /anzeige <text> (kostenpflichtig)' } })
        return
    end
    TriggerServerEvent('hrp:phone:ad', body)
end, false)

RegisterCommand('anzeigen', function() TriggerServerEvent('hrp:phone:ads') end, false)
