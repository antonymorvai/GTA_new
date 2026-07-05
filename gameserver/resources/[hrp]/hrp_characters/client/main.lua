--[[
    Client: Charakterauswahl-UI (NUI) + Spawn.
    Der Client zeigt nur an und sendet Anfragen — jede Entscheidung fällt serverseitig.
]]

local inSelection = false

local function openSelection()
    inSelection = true
    SetNuiFocus(true, true)
    DoScreenFadeOut(0)
    Wait(500)
    DoScreenFadeIn(500)
    TriggerServerEvent('hrp:characters:requestList')
end

AddEventHandler('playerSpawned', function()
    if not inSelection then
        -- Erster Spawn nach Join: Charakterauswahl statt Freemode-Spawn
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        openSelection()
    end
end)

RegisterNetEvent('hrp:characters:list', function(characters, maxSlots)
    SendNUIMessage({ action = 'list', characters = characters, maxSlots = maxSlots })
end)

RegisterNetEvent('hrp:characters:createResult', function(ok, message)
    SendNUIMessage({ action = 'createResult', ok = ok, message = message })
end)

RegisterNetEvent('hrp:characters:spawn', function(pos, char)
    inSelection = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    DoScreenFadeOut(300)
    Wait(400)

    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.h or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityHealth(ped, char.health or 200)
    SetPedArmour(ped, char.armor or 0)

    Wait(500)
    DoScreenFadeIn(500)
    TriggerEvent('chat:addMessage', {
        args = { '^2CHARAKTER', ('Willkommen zurück, %s %s.'):format(char.firstName, char.lastName) },
    })
end)

-- NUI-Callbacks
RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('hrp:characters:select', tonumber(data.characterId))
    cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('hrp:characters:create', data)
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('hrp:characters:delete', tonumber(data.characterId))
    cb({ ok = true })
end)
