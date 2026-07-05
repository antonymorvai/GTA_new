-- Justiz-Client: Gefängnis-Teleport und Geofence (Verlassen wird verhindert;
-- die Fußfessel mit Alarm für Bewährung folgt in Phase 4).

local inJail = false
local prisonCenter = nil
local PRISON_RADIUS = 120.0

RegisterNetEvent('hrp:justice:jail', function(pos)
    inJail = true
    prisonCenter = vector3(pos.x, pos.y, pos.z)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(400)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.h or 0.0)
    RemoveAllPedWeapons(ped, true)
    Wait(300)
    DoScreenFadeIn(500)

    CreateThread(function()
        while inJail do
            Wait(2000)
            local p = PlayerPedId()
            if prisonCenter and #(GetEntityCoords(p) - prisonCenter) > PRISON_RADIUS then
                SetEntityCoordsNoOffset(p, prisonCenter.x, prisonCenter.y, prisonCenter.z, false, false, false)
                TriggerEvent('chat:addMessage', { args = { '^1JUSTIZ', 'Du kannst das Gefängnis nicht verlassen.' } })
            end
        end
    end)
end)

RegisterNetEvent('hrp:justice:release', function(pos)
    inJail = false
    prisonCenter = nil
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(400)
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.h or 0.0)
    Wait(300)
    DoScreenFadeIn(500)
end)
