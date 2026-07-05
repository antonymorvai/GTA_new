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

-- /help — Befehlsübersicht nach Themen
local HELP = {
    'Allgemein: /help /inv (F2) /use /vitals /skills /mynumber /sms /tweet /anzeige',
    'Geld: /balance /deposit /withdraw /transfer /dauerauftrag /loan /givecash /payfine /myfines',
    'Fahrzeug: /buycar /garage /park /givekey /refuel /trunk(-store/-take) /myvehicles /insure /claim /scrap',
    'Immobilie: /buyhouse /enterhouse /leavehouse /givehousekey /homestorage(-store/-take)',
    'Arbeit: /duty /harvest /craft /rezepte /loadfuel /deliverfuel /stationen /repair /service /tune /bill /paybill',
    'Funk: /funk <freq> /f <text> /funkaus — Fraktion: /mdt /charge /fine /jail /revive /diagnose /treat',
}

RegisterCommand('help', function()
    for _, line in ipairs(HELP) do
        TriggerEvent('chat:addMessage', { args = { '^5HILFE', line } })
    end
end, false)

-- /givecash <serverId> <euro> — Client sendet nur die ANFRAGE; validiert wird serverseitig.
RegisterCommand('givecash', function(_, args)
    local target, euro = tonumber(args[1]), tonumber(args[2])
    if not target or not euro or euro <= 0 then
        TriggerEvent('chat:addMessage', { args = { '^1GELD', 'Nutzung: /givecash <ID> <Betrag>' } })
        return
    end
    TriggerServerEvent('hrp:money:giveCash', target, math.floor(euro * 100))
end, false)
