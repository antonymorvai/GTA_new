--[[
    Medical-Client: Bewusstlosigkeit (kein Auto-Respawn), Blutungs- und
    Hunger-Effekte. Alle Entscheidungen (wer ist down, wer darf reviven)
    trifft der Server — der Client setzt nur Darstellung/Animation um.
]]

local isDown = false
local isBleeding = false

-- Auto-Respawn von spawnmanager deaktivieren (Bewusstlosigkeit statt Respawn)
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.spawnmanager:setAutoSpawn(false)
end)

RegisterNetEvent('hrp:medical:down', function(bleedOutSeconds)
    isDown = true
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    -- An Ort und Stelle "bewusstlos" wiederbeleben statt GTA-Respawn
    CreateThread(function()
        Wait(2000)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        local newPed = PlayerPedId()
        SetEntityHealth(newPed, 105)          -- knapp über tot
        SetPedToRagdoll(newPed, 60000, 60000, 0, false, false, false)

        while isDown do
            Wait(500)
            local p = PlayerPedId()
            FreezeEntityPosition(p, false)     -- Ragdoll braucht Physik
            if not IsPedRagdoll(p) then
                SetPedToRagdoll(p, 60000, 60000, 0, false, false, false)
            end
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true)  -- Chat (/respawn) erlauben
        end
    end)
end)

RegisterNetEvent('hrp:medical:revive', function(toHospital, pos)
    isDown = false
    isBleeding = false
    local ped = PlayerPedId()
    if toHospital and pos then
        DoScreenFadeOut(400)
        Wait(500)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.h or 0.0, true, false)
        SetEntityHealth(PlayerPedId(), 160)
        Wait(300)
        DoScreenFadeIn(600)
    else
        ClearPedTasksImmediately(ped)
        SetEntityHealth(ped, 140)
    end
end)

-- Blutung: langsamer HP-Verlust bis Verband/Behandlung
RegisterNetEvent('hrp:medical:bleeding', function(active)
    if active == isBleeding then return end
    isBleeding = active
    if not active then return end
    CreateThread(function()
        while isBleeding and not isDown do
            Wait(10000)
            local ped = PlayerPedId()
            local hp = GetEntityHealth(ped)
            if hp > 110 then
                SetEntityHealth(ped, hp - 2)
            end
        end
    end)
end)

-- Verhungern/Verdursten: Schaden am eigenen Ped (Server hat die Vitals gesenkt)
RegisterNetEvent('hrp:medical:starving', function()
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    if hp > 110 then
        SetEntityHealth(ped, hp - 5)
        TriggerEvent('chat:addMessage', { args = { '^1VITAL', 'Du brauchst dringend Essen oder Wasser!' } })
    end
end)

RegisterNetEvent('hrp:medical:vitals', function(hunger, thirst)
    if hunger <= 20 or thirst <= 20 then
        TriggerEvent('chat:addMessage', {
            args = { '^3VITAL', ('Hunger: %d%% · Durst: %d%%'):format(hunger, thirst) },
        })
    end
end)

RegisterCommand('use', function(_, args)
    if not args[1] then
        TriggerEvent('chat:addMessage', { args = { '^1INVENTAR', 'Nutzung: /use <item-uuid>' } })
        return
    end
    TriggerServerEvent('hrp:inventory:use', args[1])
end, false)
