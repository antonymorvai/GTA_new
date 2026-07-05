-- Logistik-Befehle: Anfragen an den Server (Job/Ort/Ladung validiert der Server).

RegisterCommand('loadfuel', function() TriggerServerEvent('hrp:logistics:load') end, false)
RegisterCommand('deliverfuel', function() TriggerServerEvent('hrp:logistics:deliver') end, false)
RegisterCommand('stationen', function() TriggerServerEvent('hrp:logistics:stations') end, false)
