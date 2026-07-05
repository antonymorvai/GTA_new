-- Smartphone-Befehle (Basis; Phone-NUI folgt in einer späteren Phase).

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
