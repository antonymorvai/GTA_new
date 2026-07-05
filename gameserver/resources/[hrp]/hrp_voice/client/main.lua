-- Funk-Befehle: /funk <frequenz> · /f <text> (Text-Funk) · /funkaus

RegisterCommand('funk', function(_, args)
    local freq = tonumber(args[1])
    if not freq then
        TriggerEvent('chat:addMessage', { args = { '^1FUNK', 'Nutzung: /funk <frequenz> (z. B. 42.5)' } })
        return
    end
    TriggerServerEvent('hrp:voice:tune', freq)
end, false)

RegisterCommand('f', function(_, args)
    local msg = table.concat(args, ' ')
    if msg ~= '' then TriggerServerEvent('hrp:voice:transmit', msg) end
end, false)

RegisterCommand('funkaus', function() TriggerServerEvent('hrp:voice:off') end, false)
