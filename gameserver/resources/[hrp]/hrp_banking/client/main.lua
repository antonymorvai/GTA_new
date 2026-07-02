-- Banking-Befehle (Basis-UI; Bank-NUI folgt mit dem Smartphone-Banking).
-- Beträge werden in Euro eingegeben und als Cent an den Server gesendet.

local function cents(arg)
    local euro = tonumber(arg)
    if not euro or euro <= 0 then return nil end
    return math.floor(euro * 100)
end

RegisterCommand('deposit', function(_, args)
    local amount = cents(args[1])
    if not amount then
        TriggerEvent('chat:addMessage', { args = { '^1BANK', 'Nutzung: /deposit <Betrag>' } })
        return
    end
    TriggerServerEvent('hrp:banking:deposit', amount)
end, false)

RegisterCommand('withdraw', function(_, args)
    local amount = cents(args[1])
    if not amount then
        TriggerEvent('chat:addMessage', { args = { '^1BANK', 'Nutzung: /withdraw <Betrag>' } })
        return
    end
    TriggerServerEvent('hrp:banking:withdraw', amount)
end, false)

RegisterCommand('transfer', function(_, args)
    local toNumber, amount = args[1], cents(args[2])
    if not toNumber or not amount then
        TriggerEvent('chat:addMessage', { args = { '^1BANK', 'Nutzung: /transfer <Kontonummer> <Betrag>' } })
        return
    end
    TriggerServerEvent('hrp:banking:transfer', toNumber:upper(), amount, table.concat(args, ' ', 3))
end, false)

RegisterCommand('balance', function()
    TriggerServerEvent('hrp:banking:balance')
end, false)

RegisterCommand('dauerauftrag', function(_, args)
    local toNumber, amount, hours = args[1], cents(args[2]), tonumber(args[3])
    if not toNumber or not amount or not hours then
        TriggerEvent('chat:addMessage', { args = { '^1BANK', 'Nutzung: /dauerauftrag <Kontonummer> <Betrag> <IntervallStunden>' } })
        return
    end
    TriggerServerEvent('hrp:banking:standingOrder', toNumber:upper(), amount, math.floor(hours))
end, false)

RegisterCommand('duty', function()
    TriggerServerEvent('hrp:jobs:toggleDuty')
end, false)
