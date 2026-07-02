-- hrp_core Client: bewusst minimal — der Client hält keinen autoritativen Zustand.

RegisterNetEvent('hrp:money:giveCashResult', function(ok, err)
    if ok then
        TriggerEvent('chat:addMessage', { args = { '^2GELD', 'Übergabe erfolgreich.' } })
    else
        local messages = {
            insufficient_funds = 'Nicht genug Bargeld.',
            invalid_amount = 'Ungültiger Betrag.',
        }
        TriggerEvent('chat:addMessage', { args = { '^1GELD', messages[err] or 'Übergabe fehlgeschlagen.' } })
    end
end)

-- /givecash <serverId> <euro> — Client sendet nur die ANFRAGE; validiert wird serverseitig.
RegisterCommand('givecash', function(_, args)
    local target, euro = tonumber(args[1]), tonumber(args[2])
    if not target or not euro or euro <= 0 then
        TriggerEvent('chat:addMessage', { args = { '^1GELD', 'Nutzung: /givecash <ID> <Betrag>' } })
        return
    end
    TriggerServerEvent('hrp:money:giveCash', target, math.floor(euro * 100))
end, false)
