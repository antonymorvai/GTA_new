--[[
    Inventar-Client 2.0: Grid-NUI mit Drag&Drop. F2/​/inv öffnet das eigene
    Inventar; Module (Kofferraum/Lager) öffnen einen Zweit-Container per
    Server-Export. Der Client zeigt nur an — jede Aktion validiert der Server.
]]

local open = false

local function closeInventory()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

RegisterCommand('inv', function()
    if open then closeInventory() else
        open = true
        SetNuiFocus(true, true)
        TriggerServerEvent('hrp:inventory:request')
    end
end, false)

RegisterKeyMapping('inv', 'Inventar öffnen', 'keyboard', 'F2')

-- Vollständiger Zustand (eigenes Inventar + optionaler Zweit-Container)
RegisterNetEvent('hrp:inventory:open', function(state)
    if not open then
        open = true
        SetNuiFocus(true, true)
    end
    SendNUIMessage({ action = 'show', state = state })
end)

-- Überladen: spürbar langsamer (unverändert)
RegisterNetEvent('hrp:inventory:overweight', function(heavy)
    SetPedMoveRateOverride(PlayerPedId(), heavy and 0.85 or 1.0)
    if heavy then
        TriggerEvent('chat:addMessage', { args = { '^3INVENTAR', 'Du schleppst zu viel — du bist langsamer.' } })
    end
end)

RegisterNUICallback('close', function(_, cb) closeInventory() cb({ ok = true }) end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('hrp:inventory:use', data.uuid)
    Wait(250) TriggerServerEvent('hrp:inventory:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('drop', function(data, cb)
    TriggerServerEvent('hrp:inventory:drop', data.uuid)
    Wait(250) TriggerServerEvent('hrp:inventory:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('give', function(data, cb)
    local target = tonumber(data.targetId)
    if target then
        TriggerServerEvent('hrp:inventory:give', target, data.uuid)
        Wait(250) TriggerServerEvent('hrp:inventory:refresh')
    end
    cb({ ok = true })
end)

-- Drag&Drop zwischen den beiden Panels
RegisterNUICallback('move', function(data, cb)
    if data.uuid and (data.dest == 'primary' or data.dest == 'secondary') then
        TriggerServerEvent('hrp:inventory:move', data.uuid, data.dest)
    end
    cb({ ok = true })
end)
