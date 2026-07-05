--[[
    Inventar-Client: NUI öffnen/schließen (F2 oder /inv), Anfragen an den
    Server weiterreichen. Der Client kennt nur Anzeige-Daten — jede Aktion
    (benutzen/geben/ablegen) validiert der Server erneut.
]]

local open = false

local function closeInventory()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function openInventory()
    open = true
    SetNuiFocus(true, true)
    TriggerServerEvent('hrp:inventory:request')
end

RegisterCommand('inv', function()
    if open then closeInventory() else openInventory() end
end, false)

RegisterKeyMapping('inv', 'Inventar öffnen', 'keyboard', 'F2')

RegisterNetEvent('hrp:inventory:contents', function(items, weight, maxWeight)
    if not open then return end
    SendNUIMessage({ action = 'show', items = items, weight = weight, maxWeight = maxWeight })
end)

RegisterNUICallback('close', function(_, cb)
    closeInventory()
    cb({ ok = true })
end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('hrp:inventory:use', data.uuid)
    Wait(250)
    TriggerServerEvent('hrp:inventory:request')
    cb({ ok = true })
end)

RegisterNUICallback('drop', function(data, cb)
    TriggerServerEvent('hrp:inventory:drop', data.uuid)
    Wait(250)
    TriggerServerEvent('hrp:inventory:request')
    cb({ ok = true })
end)

RegisterNUICallback('give', function(data, cb)
    local target = tonumber(data.targetId)
    if target then
        TriggerServerEvent('hrp:inventory:give', target, data.uuid)
        Wait(250)
        TriggerServerEvent('hrp:inventory:request')
    end
    cb({ ok = true })
end)
