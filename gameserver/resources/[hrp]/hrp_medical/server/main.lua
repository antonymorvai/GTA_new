--[[
    hrp_medical – Verletzungssystem & Rettungsdienst-Basis:

    - weaponDamageEvent (server-seitig!) -> combat.damage-Events mit Trefferzone,
      Waffe, Distanz; probabilistische Verletzungen (character_injuries)
    - Down/Bewusstlosigkeit statt Respawn: combat.down mit Beteiligten,
      Bleed-out-Timer, EMS-Revive oder Klinik-Respawn
    - Krankenakten (medical_records), Diagnose je Trefferzone
    - Vitals-Simulation: Hunger/Durst sinken, Items stellen wieder her

    Kill-Akte (ACP): combat.down + die letzten 60 s Bewegungsdaten liegen
    bereits im Log-Store (position_samples) — der Drill-Down folgt in Phase 5.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs

local HOSPITAL = vector4(298.6, -584.4, 43.3, 70.0)

-- downState[src] = {since, bleedOutAt, canRespawn}
local downState = {}

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2MEDIC' or '^1MEDIC', msg } })
end

local function isMedic(src)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return false end
    local job = Jobs:GetJob(ident.characterId)
    return job ~= nil and job.name == 'ems' and job.on_duty == 1
end

-- ---------------------------------------------------------------------------
-- Trefferzonen-Mapping (GTA-Bone-Komponenten -> grobe Zonen)
-- ---------------------------------------------------------------------------

local function zoneFromComponent(component)
    -- weaponDamageEvent hitComponent: 0=Torso-Standard; grobe Zuordnung
    local map = {
        [0] = 'torso', [1] = 'torso', [2] = 'torso', [3] = 'left_arm',
        [4] = 'left_arm', [5] = 'left_arm', [6] = 'right_arm', [7] = 'right_arm',
        [8] = 'right_arm', [9] = 'left_leg', [10] = 'left_leg', [11] = 'left_leg',
        [12] = 'right_leg', [13] = 'right_leg', [14] = 'right_leg',
        [15] = 'head', [16] = 'head', [17] = 'head', [18] = 'head', [19] = 'head', [20] = 'head',
    }
    return map[component] or 'torso'
end

local ZONE_LABELS = {
    head = 'Kopf', torso = 'Torso', left_arm = 'linker Arm', right_arm = 'rechter Arm',
    left_leg = 'linkes Bein', right_leg = 'rechtes Bein',
}

-- ---------------------------------------------------------------------------
-- Kampf-Logging: jeder registrierte Waffenschaden
-- ---------------------------------------------------------------------------

AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end
    local attacker = Core:GetPlayerIdentity(src)
    if not attacker then return end

    -- Ziel auflösen (nur Spieler-Ziele erzeugen Verletzungen/volle Akten)
    local hitGlobal = data.hitGlobalId ~= 0 and data.hitGlobalId or (data.hitGlobalIds and data.hitGlobalIds[1])
    local targetEntity = hitGlobal and NetworkGetEntityFromNetworkId(hitGlobal) or 0
    local targetSrc = targetEntity ~= 0 and NetworkGetEntityOwner(targetEntity) or nil
    local targetIdent, targetIsPlayer = nil, false
    if targetSrc and GetPlayerPed(targetSrc) == targetEntity then
        targetIdent = Core:GetPlayerIdentity(targetSrc)
        targetIsPlayer = targetIdent ~= nil and targetIdent.characterId ~= nil
    end

    local zone = zoneFromComponent(data.hitComponent)
    local attackerPed = GetPlayerPed(src)
    local distance = 0.0
    if targetEntity ~= 0 and attackerPed ~= 0 then
        distance = #(GetEntityCoords(attackerPed) - GetEntityCoords(targetEntity))
    end

    Core:Log(src, 'combat.damage', {
        target = targetIsPlayer and { kind = 'character', id = tostring(targetIdent.characterId) } or nil,
        payload = {
            weaponHash = data.weaponType,
            damage = data.weaponDamage,
            zone = zone,
            hitComponent = data.hitComponent,
            distance = math.floor(distance * 10) / 10,
            targetCharacterId = targetIsPlayer and targetIdent.characterId or nil,
            targetType = targetIsPlayer and 'player' or 'other',
        },
    })

    -- Verletzung erzeugen (Wahrscheinlichkeit & Schwere schadensabhängig, Tuning)
    if targetIsPlayer then
        local dmg = tonumber(data.weaponDamage) or 0
        local chance = Core:TuningGet('medical.injury_chance_base', 0.35)
            + dmg / Core:TuningGet('medical.injury_damage_divisor', 200)
        if math.random() < math.min(chance, 0.95) then
            local severity = dmg >= 60 and 3 or (dmg >= 25 and 2 or 1)
            local bleeding = (severity >= 2 and math.random() < 0.6) and 1 or 0
            Db.insert([[
                INSERT INTO character_injuries (character_id, zone, kind, severity, bleeding)
                VALUES (?, ?, 'bullet', ?, ?)
            ]], { targetIdent.characterId, zone, severity, bleeding })
            if bleeding == 1 then
                TriggerClientEvent('hrp:medical:bleeding', targetSrc, true)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Down / Bewusstlosigkeit statt Respawn
-- ---------------------------------------------------------------------------

local function setCharacterState(characterId, before, after, cause, src)
    Db.update('UPDATE characters SET state = ? WHERE id = ?', { after, characterId })
    Core:Log(src, 'character.state_change', {
        target = { kind = 'character', id = tostring(characterId) },
        payload = { characterId = characterId, before = before, after = after, cause = cause },
    })
end

local function handleDown(src, killerSrc, cause, weaponHash)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    if downState[src] then return end

    local bleedOutSeconds = Core:TuningGet('medical.bleedout_seconds', 300)
    downState[src] = { since = os.time(), bleedOutAt = os.time() + bleedOutSeconds }

    local killerIdent = killerSrc and killerSrc ~= src and Core:GetPlayerIdentity(killerSrc) or nil
    setCharacterState(ident.characterId, 'alive', 'unconscious', cause, src)

    Core:Log(src, 'combat.down', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        payload = {
            characterId = ident.characterId,
            cause = cause,
            weaponHash = weaponHash,
            killerCharacterId = killerIdent and killerIdent.characterId or nil,
            killerAccountId = killerIdent and killerIdent.accountId or nil,
            bleedOutSeconds = bleedOutSeconds,
        },
    })

    TriggerClientEvent('hrp:medical:down', src, bleedOutSeconds)
    reply(src, false, ('Du bist bewusstlos. Ein Notruf wurde abgesetzt — nach %d Minuten kannst du /respawn nutzen.')
        :format(math.floor(bleedOutSeconds / 60)))
end

-- baseevents ist client-getriggert -> server-seitig validieren (Ped wirklich tot?)
RegisterNetEvent('baseevents:onPlayerDied', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped == 0 or GetEntityHealth(ped) > 0 then return end
    handleDown(src, nil, 'died', nil)
end)

RegisterNetEvent('baseevents:onPlayerKilled', function(killerId, deathData)
    local src = source
    local ped = GetPlayerPed(src)
    if ped == 0 or GetEntityHealth(ped) > 0 then return end
    handleDown(src, tonumber(killerId), 'killed',
        type(deathData) == 'table' and deathData.weaponhash or nil)
end)

AddEventHandler('playerDropped', function()
    downState[source] = nil
end)

-- Revive durch EMS
RegisterCommand('revive', function(src, args)
    if src == 0 then return end
    if not isMedic(src) then return reply(src, false, 'Nur Rettungsdienst im Dienst.') end
    local targetSrc = tonumber(args[1])
    if not targetSrc or not downState[targetSrc] then return reply(src, false, 'Dieser Spieler ist nicht bewusstlos.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 5.0 then
        return reply(src, false, 'Du bist zu weit weg.')
    end

    local medic = Core:GetPlayerIdentity(src)
    local patient = Core:GetPlayerIdentity(targetSrc)
    downState[targetSrc] = nil
    setCharacterState(patient.characterId, 'unconscious', 'alive', 'revived', targetSrc)

    Db.insert('INSERT INTO medical_records (character_id, author_character_id, entry) VALUES (?, ?, ?)',
        { patient.characterId, medic.characterId, 'Reanimation vor Ort.' })

    Core:Log(src, 'medical.revive', {
        target = { kind = 'character', id = tostring(patient.characterId) },
        payload = { patientCharacterId = patient.characterId, medicCharacterId = medic.characterId },
    })

    TriggerClientEvent('hrp:medical:revive', targetSrc, false)
    reply(src, true, 'Patient reanimiert.')
    reply(targetSrc, true, 'Du wurdest reanimiert.')
end, false)

-- Respawn in die Klinik (erst nach Bleed-out erlaubt)
RegisterCommand('respawn', function(src)
    if src == 0 then return end
    local state = downState[src]
    if not state then return end
    if os.time() < state.bleedOutAt then
        return reply(src, false, ('Noch %d Sekunden bis zur Aufgabe.'):format(state.bleedOutAt - os.time()))
    end
    local ident = Core:GetPlayerIdentity(src)
    downState[src] = nil
    setCharacterState(ident.characterId, 'unconscious', 'alive', 'hospital_respawn', src)

    Db.insert('INSERT INTO medical_records (character_id, author_character_id, entry) VALUES (?, ?, ?)',
        { ident.characterId, ident.characterId, 'Einlieferung Pillbox Medical (bewusstlos aufgefunden).' })

    -- Unbehandelte Verletzungen gelten nach Klinik als grundversorgt
    Db.update('UPDATE character_injuries SET treated_at = NOW(3) WHERE character_id = ? AND treated_at IS NULL',
        { ident.characterId })

    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 10000) end)
    TriggerClientEvent('hrp:medical:revive', src, true, { x = HOSPITAL.x, y = HOSPITAL.y, z = HOSPITAL.z, h = HOSPITAL.w })
end, false)

-- ---------------------------------------------------------------------------
-- Diagnose & Behandlung (EMS)
-- ---------------------------------------------------------------------------

RegisterCommand('diagnose', function(src, args)
    if src == 0 then return end
    if not isMedic(src) then return reply(src, false, 'Nur Rettungsdienst im Dienst.') end
    local targetSrc = tonumber(args[1])
    local patient = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not patient or not patient.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 5.0 then
        return reply(src, false, 'Du bist zu weit weg.')
    end

    local medic = Core:GetPlayerIdentity(src)
    Core:Log(src, 'medical.diagnose', {
        target = { kind = 'character', id = tostring(patient.characterId) },
        payload = { patientCharacterId = patient.characterId, medicCharacterId = medic.characterId },
    })

    local injuries = Db.query([[
        SELECT zone, kind, severity, bleeding FROM character_injuries
        WHERE character_id = ? AND treated_at IS NULL ORDER BY severity DESC
    ]], { patient.characterId }) or {}
    if #injuries == 0 then return reply(src, true, 'Keine unbehandelten Verletzungen.') end
    for _, inj in ipairs(injuries) do
        reply(src, true, ('%s: %s (Schwere %d)%s'):format(
            ZONE_LABELS[inj.zone] or inj.zone, inj.kind, inj.severity,
            inj.bleeding == 1 and ' — BLUTET' or ''))
    end
end, false)

RegisterCommand('treat', function(src, args)
    if src == 0 then return end
    if not isMedic(src) then return reply(src, false, 'Nur Rettungsdienst im Dienst.') end
    local targetSrc = tonumber(args[1])
    local patient = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not patient or not patient.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 5.0 then
        return reply(src, false, 'Du bist zu weit weg.')
    end

    local medic = Core:GetPlayerIdentity(src)
    local affected = Db.update([[
        UPDATE character_injuries SET treated_at = NOW(3), treated_by = ?
        WHERE character_id = ? AND treated_at IS NULL
    ]], { medic.characterId, patient.characterId })
    if affected == 0 then return reply(src, true, 'Keine unbehandelten Verletzungen.') end

    local note = table.concat(args, ' ', 2)
    Db.insert('INSERT INTO medical_records (character_id, author_character_id, entry) VALUES (?, ?, ?)',
        { patient.characterId, medic.characterId,
          ('Behandlung: %d Verletzung(en) versorgt.%s'):format(affected, note ~= '' and (' Notiz: ' .. note) or '') })

    Core:Log(src, 'medical.treat', {
        target = { kind = 'character', id = tostring(patient.characterId) },
        payload = { patientCharacterId = patient.characterId, medicCharacterId = medic.characterId,
                    injuriesTreated = affected },
    })
    TriggerClientEvent('hrp:medical:bleeding', targetSrc, false)
    reply(src, true, ('%d Verletzung(en) behandelt.'):format(affected))
    reply(targetSrc, true, 'Du wurdest medizinisch versorgt.')
end, false)

-- ---------------------------------------------------------------------------
-- Vitals: Hunger/Durst sinken; Items stellen wieder her
-- ---------------------------------------------------------------------------

local ITEM_EFFECTS = {
    water_bottle = { thirst = 40 },
    bread        = { hunger = 35 },
    bandage      = { stopBleeding = true },
}

AddEventHandler('hrp:items:used', function(src, itemName)
    local effect = ITEM_EFFECTS[itemName]
    if not effect then return end
    local ident = Core:GetPlayerIdentity(src)

    if effect.hunger or effect.thirst then
        Db.update([[
            UPDATE character_vitals
            SET hunger = LEAST(100, hunger + ?), thirst = LEAST(100, thirst + ?)
            WHERE character_id = ?
        ]], { effect.hunger or 0, effect.thirst or 0, ident.characterId })
        reply(src, true, effect.thirst and 'Du hast getrunken.' or 'Du hast gegessen.')
    end
    if effect.stopBleeding then
        Db.update('UPDATE character_injuries SET bleeding = 0 WHERE character_id = ? AND treated_at IS NULL',
            { ident.characterId })
        TriggerClientEvent('hrp:medical:bleeding', src, false)
        reply(src, true, 'Blutung gestoppt (Verband angelegt).')
    end
end)

CreateThread(function()
    while true do
        local minutes = Core:TuningGet('medical.vitals_tick_minutes', 5)
        Wait(math.max(1, minutes) * 60000)

        local hungerRate = Core:TuningGet('medical.hunger_per_tick', 3)
        local thirstRate = Core:TuningGet('medical.thirst_per_tick', 4)

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            if ident and ident.characterId then
                Db.update([[
                    UPDATE character_vitals
                    SET hunger = GREATEST(0, hunger - ?), thirst = GREATEST(0, thirst - ?)
                    WHERE character_id = ?
                ]], { hungerRate, thirstRate, ident.characterId })

                local vitals = Db.single('SELECT hunger, thirst FROM character_vitals WHERE character_id = ?',
                    { ident.characterId })
                if vitals then
                    TriggerClientEvent('hrp:medical:vitals', src, vitals.hunger, vitals.thirst)
                    if vitals.hunger == 0 or vitals.thirst == 0 then
                        TriggerClientEvent('hrp:medical:starving', src)
                    end
                end
            end
        end
    end
end)

RegisterCommand('vitals', function(src)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local v = Db.single('SELECT hunger, thirst FROM character_vitals WHERE character_id = ?', { ident.characterId })
    if v then reply(src, true, ('Hunger: %d%% · Durst: %d%%'):format(v.hunger, v.thirst)) end
end, false)
