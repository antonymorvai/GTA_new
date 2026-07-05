-- Drogen-Client: nur Anfragen — Location, Bestand, Preise und Spuren
-- entscheidet ausschließlich der Server.

RegisterCommand('process', function()
    TriggerServerEvent('hrp:drugs:process')
end, false)

RegisterCommand('sellweed', function(_, args)
    if not args[1] then
        TriggerEvent('chat:addMessage', { args = { '^1DEAL', 'Nutzung: /sellweed <item-uuid>' } })
        return
    end
    TriggerServerEvent('hrp:drugs:sell', args[1])
end, false)
