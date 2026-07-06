-- Polizei-Client: MDT-Tablet-NUI + Handschellen-Zustand.

local mdtOpen = false

local function closeMdt()
    mdtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mdtHide' })
end

RegisterCommand('mdt_tablet', function()
    if mdtOpen then return closeMdt() end
    TriggerServerEvent('hrp:police:mdtOpen')
end, false)
RegisterKeyMapping('mdt_tablet', 'MDT-Tablet öffnen', 'keyboard', 'F6')

RegisterNetEvent('hrp:police:mdtOpen', function(info)
    mdtOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'mdtShow', info = info })
end)

RegisterNetEvent('hrp:police:mdtResult', function(kind, data)
    if mdtOpen then SendNUIMessage({ action = 'mdtResult', kind = kind, data = data }) end
end)

RegisterNUICallback('mdtClose', function(_, cb) closeMdt() cb({}) end)
RegisterNUICallback('mdtQuery', function(d, cb)
    if d.kind == 'person' then TriggerServerEvent('hrp:police:mdtPerson', d.query)
    elseif d.kind == 'vehicle' then TriggerServerEvent('hrp:police:mdtVehicle', d.query)
    elseif d.kind == 'wanted' then TriggerServerEvent('hrp:police:mdtWanted')
    elseif d.kind == 'serial' then TriggerServerEvent('hrp:police:mdtSerial', d.query) end
    cb({})
end)

local isCuffed = false

RegisterNetEvent('hrp:police:cuffed', function(state)
    isCuffed = state
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
        TriggerEvent('chat:addMessage', { args = { '^1POLIZEI', 'Dir wurden Handschellen angelegt.' } })
        CreateThread(function()
            while isCuffed do
                Wait(0)
                local p = PlayerPedId()
                DisableControlAction(0, 24, true)   -- Angriff
                DisableControlAction(0, 25, true)   -- Zielen
                DisableControlAction(0, 21, true)   -- Sprint
                DisableControlAction(0, 22, true)   -- Springen
                DisableControlAction(0, 44, true)   -- Deckung
                DisableControlAction(0, 75, true)   -- Fahrzeug verlassen
                if not IsEntityPlayingAnim(p, 'mp_arresting', 'idle', 3) then
                    TaskPlayAnim(p, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
        end)
    else
        ClearPedTasks(ped)
    end
end)
