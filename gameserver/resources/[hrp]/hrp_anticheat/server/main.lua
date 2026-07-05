--[[
    hrp_anticheat – server-seitige Plausibilitätsprüfungen.

    Philosophie: ERKENNEN und LOGGEN zuerst (security.anticheat-Events ->
    ACP/Anomalie-Analyse), automatisch KICKEN nur wenn per Tuning aktiviert.
    Der eigentliche Schutz ist die server-autoritative Architektur (kein
    Client-Event mutiert Zustand direkt) — dieses Modul fängt zusätzlich ab,
    was die Engine dem Client erlaubt (Teleport, Godmode-Werte, Entity-Spam,
    Explosionen).

    Legitime Teleports (Garage, Immobilie, Haft, Klinik, Admin) melden sich
    über den Export AllowTeleport(src, ms) an, sonst würde jedes Feature des
    Frameworks Alarme auslösen.
]]

local Core = exports.hrp_core

-- Strike-Verwaltung
local strikes = {}         -- strikes[src] = n
local teleportGrants = {}  -- teleportGrants[src] = Ablauf-Timestamp (ms)
local lastPos = {}         -- lastPos[src] = vector3

--- Legitimen Teleport ankündigen (von Framework-Modulen genutzt).
function AllowTeleport(src, ms)
    teleportGrants[src] = GetGameTimer() + (ms or 5000)
end
exports('AllowTeleport', AllowTeleport)

local function detect(src, check, detail)
    strikes[src] = (strikes[src] or 0) + 1
    Core:Log(src, 'security.anticheat', {
        payload = {
            check = check,
            detail = detail,
            strikes = strikes[src],
        },
    })

    local kickAt = Core:TuningGet('anticheat.kick_strikes', 0)  -- 0 = nie kicken (nur loggen)
    if kickAt > 0 and strikes[src] >= kickAt then
        DropPlayer(src, 'Verbindungsfehler (AC). Bei wiederholtem Auftreten: Support-Ticket.')
    end
end

-- ---------------------------------------------------------------------------
-- Teleport-/Geschwindigkeits-Erkennung (5-s-Raster)
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(5000)
        local maxDist = Core:TuningGet('anticheat.max_distance_per_5s', 400.0)
        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            local ped = GetPlayerPed(src)
            if ident and ident.characterId and ped ~= 0 then
                local pos = GetEntityCoords(ped)
                local prev = lastPos[src]
                lastPos[src] = pos
                if prev then
                    local dist = #(pos - prev)
                    local granted = teleportGrants[src] and GetGameTimer() < teleportGrants[src]
                    if dist > maxDist and not granted then
                        detect(src, 'teleport', {
                            distance = math.floor(dist),
                            from = { x = prev.x, y = prev.y, z = prev.z },
                            to = { x = pos.x, y = pos.y, z = pos.z },
                        })
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Godmode-/Wertebereichs-Erkennung
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(10000)
        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            local ped = GetPlayerPed(src)
            if ident and ident.characterId and ped ~= 0 then
                local health = GetEntityHealth(ped)
                local armor = GetPedArmour(ped)
                if health > 200 then
                    detect(src, 'health_range', { health = health })
                end
                if armor > 100 then
                    detect(src, 'armor_range', { armor = armor })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Entity-Spam / Blacklist-Modelle (OneSync entityCreating ist abbrechbar)
-- ---------------------------------------------------------------------------

local BLACKLISTED_MODELS = {}
for _, name in ipairs({
    'kosatka', 'jet', 'lazer', 'hydra', 'rhino', 'khanjali',
    'oppressor', 'oppressor2', 'cargoplane', 'titan',
}) do
    BLACKLISTED_MODELS[joaat(name)] = name
end

AddEventHandler('entityCreating', function(entity)
    local model = GetEntityModel(entity)
    local name = BLACKLISTED_MODELS[model]
    if not name then return end

    local owner = NetworkGetFirstEntityOwner(entity)
    CancelEvent()
    if owner and owner > 0 then
        detect(owner, 'blacklisted_entity', { model = name })
    end
end)

-- ---------------------------------------------------------------------------
-- Explosions-Überwachung (immer loggen; Unterdrückung per Tuning)
-- ---------------------------------------------------------------------------

AddEventHandler('explosionEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end

    Core:Log(src, 'security.anticheat', {
        payload = {
            check = 'explosion',
            detail = {
                explosionType = data and data.explosionType,
                x = data and data.posX, y = data and data.posY, z = data and data.posZ,
            },
            strikes = strikes[src] or 0,
        },
    })

    if Core:TuningGet('anticheat.cancel_explosions', false) == true then
        CancelEvent()
    end
end)

AddEventHandler('playerDropped', function()
    strikes[source] = nil
    teleportGrants[source] = nil
    lastPos[source] = nil
end)
