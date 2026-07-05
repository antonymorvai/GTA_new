-- /harvest — Anfrage an den Server; Pool-Nähe, Bestand und Ertrag prüft der Server.

RegisterCommand('harvest', function()
    TriggerServerEvent('hrp:resources:harvest')
end, false)
