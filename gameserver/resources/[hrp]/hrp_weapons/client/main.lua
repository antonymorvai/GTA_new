--[[
    Waffen-Client: zählt Schüsse lokal (IsPedShooting) und meldet sie
    gebatcht (5 s) — der Server validiert gegen die geladene Munition.
    Manipulierte Meldungen können nie MEHR Munition erzeugen, nur den
    Zähler der eigenen Waffe erhöhen.
]]

local isEquipped = false

RegisterNetEvent('hrp:weapons:equipped', function(state)
    isEquipped = state
end)

CreateThread(function()
    local pending = 0
    local lastFlush = GetGameTimer()
    while true do
        Wait(isEquipped and 50 or 500)
        if isEquipped and IsPedShooting(PlayerPedId()) then
            pending = pending + 1
        end
        if pending > 0 and (GetGameTimer() - lastFlush) > 5000 then
            TriggerServerEvent('hrp:weapons:shots', math.min(pending, 60))
            pending = 0
            lastFlush = GetGameTimer()
        end
    end
end)
