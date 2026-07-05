--[[
    hrp_drugs – mehrstufige illegale Kette (Cannabis als erste Referenzkette):

    1. BESCHAFFUNG: weed_raw über den Farming-Pool (hrp_resources, Grapeseed)
    2. VERARBEITUNG: /process an der Verarbeitungs-Location (Skill crafting,
       Qualität skaliert mit Level) -> weed_packed mit quality-Metadaten
    3. VERTRIEB: /sellweed an AKTIVEN Deal-Spots (rotieren via Director):
       - Preis dynamisch: Basispreis x Qualität x Territoriums-Modifikator
       - Skalierung mit Cop-Anzahl im Dienst (weniger Cops = geringerer Preis,
         mehr Cops = mehr Risiko-Aufschlag, aber höhere Spuren-Chance)
       - Jeder Verkauf hinterlässt mit Wahrscheinlichkeit eine SPUR
         (crime.trace) — Ermittlungsansatz für die Polizei, Dispatch-Chance

    Jede Stufe ist vollständig geloggt: item.* + money.* + drug.* + crime.trace.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Inv = exports.hrp_inventory
local Skills = exports.hrp_skills
local Territories = exports.hrp_territories
local Jobs = exports.hrp_jobs
local Logger = exports.hrp_logger

local PROCESS_LOCATION = vector3(2434.9, 4969.2, 42.3)   -- Scheune Grapeseed

local spots = {}

local function loadSpots()
    spots = Db.query('SELECT * FROM deal_spots') or {}
end
MySQL.ready(loadSpots)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2DEAL' or '^1DEAL', msg } })
end

local function copsOnDuty()
    local count = 0
    for _, srcStr in ipairs(GetPlayers()) do
        local ident = Core:GetPlayerIdentity(tonumber(srcStr))
        if ident and ident.characterId then
            local job = Jobs:GetJob(ident.characterId)
            if job and job.name == 'police' and job.on_duty == 1 then count = count + 1 end
        end
    end
    return count
end

-- ---------------------------------------------------------------------------
-- Verarbeitung
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:drugs:process', { rate = 0.3, burst = 2 }, function(src)
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - PROCESS_LOCATION) > 15.0 then
        return reply(src, false, 'Hier kannst du nichts verarbeiten.')
    end

    local ident = Core:GetPlayerIdentity(src)
    local batch = Core:TuningGet('drugs.process_batch_size', 5)

    -- Rohware im Inventar suchen
    local raw
    for _, it in ipairs(Inv:GetContainer('character', ident.characterId) or {}) do
        if it.name == 'weed_raw' and it.quantity >= batch then raw = it break end
    end
    if not raw then
        return reply(src, false, ('Du brauchst mindestens %dx Rohware.'):format(batch))
    end

    local correlationId = Logger:NewCorrelationId()
    local ok = Inv:Consume(raw.uuid, batch, { correlationId = correlationId, srcForLog = src })
    if not ok then return reply(src, false, 'Verarbeitung fehlgeschlagen.') end

    -- Qualität skaliert mit Crafting-Skill (+ Zufallsstreuung)
    local level = Skills:GetLevel(ident.characterId, 'crafting')
    local quality = math.min(100, 40 + level * 4 + math.random(0, 15))

    local uuid, err = Inv:Create('weed_packed', batch, 'drug.process',
        { type = 'character', id = ident.characterId },
        { createdBy = ident.characterId, quality = quality,
          correlationId = correlationId, srcForLog = src })
    if not uuid then
        return reply(src, false, err == 'too_heavy' and 'Du kannst nicht mehr tragen.' or 'Verarbeitung fehlgeschlagen.')
    end

    Core:Log(src, 'drug.process', {
        target = { kind = 'item', id = uuid },
        correlationId = correlationId,
        payload = { input = 'weed_raw', output = 'weed_packed', quantity = batch,
                    quality = quality, skillLevel = level },
    })
    Skills:AddXp(ident.characterId, 'crafting', Core:TuningGet('drugs.xp_per_process', 20), src)
    reply(src, true, ('%dx Päckchen hergestellt (Qualität %d%%).'):format(batch, quality))
end)

-- ---------------------------------------------------------------------------
-- Verkauf an aktiven Deal-Spots
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:drugs:sell', {
    rate = 0.3, burst = 2,
    schema = { { type = 'string', maxLen = 36, pattern = '^[%x%-]+$' } },
}, function(src, uuid)
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)

    local atSpot
    for _, spot in ipairs(spots) do
        if spot.active == 1 and #(pos - vector3(spot.pos_x, spot.pos_y, spot.pos_z)) <= 20.0 then
            atSpot = spot break
        end
    end
    if not atSpot then return reply(src, false, 'Hier will gerade niemand kaufen. Die Spots wechseln...') end

    local ident = Core:GetPlayerIdentity(src)

    local item
    for _, it in ipairs(Inv:GetContainer('character', ident.characterId) or {}) do
        if it.uuid == uuid and it.name == 'weed_packed' then item = it break end
    end
    if not item then return reply(src, false, 'Du hast dieses Päckchen nicht.') end

    -- Preis: Basis x Qualität x Territorium x Cop-Skalierung
    local basePrice = Core:TuningGet('drugs.weed_base_price', 4500)       -- Cent/Stück
    local minCops = Core:TuningGet('drugs.min_cops', 0)
    local cops = copsOnDuty()
    if cops < minCops then
        return reply(src, false, 'Die Straßen sind zu ruhig — keine Abnehmer (zu wenig Polizei im Dienst).')
    end
    local copFactor = math.min(1.0 + cops * Core:TuningGet('drugs.cop_price_bonus', 0.05), 1.5)
    local qualityFactor = (item.quality or 50) / 100 + 0.5                -- 0.5 .. 1.5
    local territoryFactor, territory = Territories:GetSaleModifier(pos.x, pos.y, ident.characterId)

    local unitPrice = math.floor(basePrice * qualityFactor * territoryFactor * copFactor)
    local total = unitPrice * item.quantity
    local correlationId = Logger:NewCorrelationId()

    local destroyed = Inv:Destroy(uuid, 'drug.sale', { correlationId = correlationId, srcForLog = src })
    if not destroyed then return reply(src, false, 'Verkauf fehlgeschlagen.') end
    Core:MoneyCreate(ident.characterId, 'cash', total, 'drug.sale', { correlationId = correlationId })

    Core:Log(src, 'drug.sale', {
        target = { kind = 'item', id = uuid },
        correlationId = correlationId,
        payload = {
            item = 'weed_packed', quantity = item.quantity, quality = item.quality,
            unitPrice = unitPrice, total = total, spotId = atSpot.id,
            territoryId = territory and territory.id or nil,
            copsOnDuty = cops,
            factors = { quality = qualityFactor, territory = territoryFactor, cops = copFactor },
        },
    })

    -- Territoriums-Einfluss für die eigene Gang
    local gang = Territories:GangOf(ident.characterId)
    if gang and territory then
        Territories:AddInfluence(territory.id, gang.id,
            Core:TuningGet('territories.influence_per_deal', 1.5), 'drug_sale', src)
    end

    -- SPUREN: Wahrscheinlichkeit steigt mit Cop-Anzahl und Verkaufsvolumen
    local traceChance = Core:TuningGet('drugs.trace_chance_base', 0.15)
        + cops * Core:TuningGet('drugs.trace_chance_per_cop', 0.02)
    if math.random() < math.min(traceChance, 0.6) then
        Core:Log(src, 'crime.trace', {
            payload = {
                crime = 'drug_sale', spotId = atSpot.id, spotLabel = atSpot.label,
                hint = 'Zeugen haben einen Deal beobachtet',
                suspectCharacterId = ident.characterId,   -- nur im Log-Store, nicht in-game!
            },
        })
        -- Dispatch an Cops im Dienst (ohne Täter-Identität — Ermittlung in-RP)
        if math.random() < Core:TuningGet('drugs.dispatch_chance', 0.5) then
            for _, srcStr in ipairs(GetPlayers()) do
                local pIdent = Core:GetPlayerIdentity(tonumber(srcStr))
                if pIdent and pIdent.characterId then
                    local job = Jobs:GetJob(pIdent.characterId)
                    if job and job.name == 'police' and job.on_duty == 1 then
                        TriggerClientEvent('chat:addMessage', tonumber(srcStr), {
                            args = { '^4DISPATCH', ('Verdächtige Aktivität gemeldet: %s'):format(atSpot.label) },
                        })
                    end
                end
            end
        end
    end

    Skills:AddXp(ident.characterId, 'crafting', 5, src)
    reply(src, true, ('%dx verkauft für %s $ (Stück: %s $).'):format(
        item.quantity, string.format('%.2f', total / 100), string.format('%.2f', unitPrice / 100)))
end)

-- ---------------------------------------------------------------------------
-- Konsum & Sucht: Wirkung senkt Stress, Toleranz baut sich auf, Entzug
-- erzeugt Stress. Sucht heilt nur durch lange Abstinenz (oder später Reha).
-- ---------------------------------------------------------------------------

AddEventHandler('hrp:items:used', function(src, itemName, uuid)
    if itemName ~= 'weed_packed' then return end
    local ident = Core:GetPlayerIdentity(src)

    local addictionGain = Core:TuningGet('drugs.addiction_per_use', 5)
    local stressRelief = Core:TuningGet('drugs.stress_relief', 30)

    MySQL.update.await([[
        INSERT INTO character_addictions (character_id, substance, level)
        VALUES (?, 'weed', ?)
        ON DUPLICATE KEY UPDATE level = LEAST(100, level + ?), last_consumed_at = NOW(3)
    ]], { ident.characterId, addictionGain, addictionGain })
    MySQL.update.await(
        'UPDATE character_vitals SET stress = GREATEST(0, stress - ?) WHERE character_id = ?',
        { stressRelief, ident.characterId })

    local level = MySQL.scalar.await(
        "SELECT level FROM character_addictions WHERE character_id = ? AND substance = 'weed'",
        { ident.characterId })

    Core:Log(src, 'drug.consume', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        payload = { substance = 'weed', stressRelief = stressRelief, addictionLevel = level },
    })
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2RAUSCH', level >= 60 and 'Du fühlst dich entspannt... aber du BRAUCHST das inzwischen.'
            or 'Du fühlst dich entspannt.' },
    })
end)

-- Entzugs-/Abbau-Tick
CreateThread(function()
    while true do
        local minutes = Core:TuningGet('drugs.withdrawal_tick_minutes', 10)
        Wait(math.max(1, minutes) * 60000)
        local threshold = Core:TuningGet('drugs.withdrawal_threshold', 30)
        local withdrawalHours = Core:TuningGet('drugs.withdrawal_after_hours', 2)
        local stressPerTick = Core:TuningGet('drugs.withdrawal_stress', 6)

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            if ident and ident.characterId then
                local addiction = MySQL.single.await([[
                    SELECT level, TIMESTAMPDIFF(HOUR, last_consumed_at, NOW(3)) AS clean_hours
                    FROM character_addictions WHERE character_id = ? AND substance = 'weed'
                ]], { ident.characterId })

                if addiction and addiction.level >= threshold and addiction.clean_hours >= withdrawalHours then
                    -- Entzug: Stress steigt, Symptome
                    MySQL.update.await(
                        'UPDATE character_vitals SET stress = LEAST(100, stress + ?) WHERE character_id = ?',
                        { stressPerTick, ident.characterId })
                    TriggerClientEvent('chat:addMessage', src, {
                        args = { '^1ENTZUG', 'Deine Hände zittern — du brauchst Stoff oder musst durchhalten.' },
                    })
                elseif addiction and addiction.level > 0 and addiction.clean_hours >= 24 then
                    -- Langsame Heilung nach 24 h Abstinenz
                    MySQL.update.await(
                        "UPDATE character_addictions SET level = GREATEST(0, level - 2) WHERE character_id = ? AND substance = 'weed'",
                        { ident.characterId })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Spot-Rotation (Director-Hook)
-- ---------------------------------------------------------------------------

local function rotateSpots()
    local activeCount = Core:TuningGet('drugs.active_spots', 2)
    Db.update('UPDATE deal_spots SET active = 0')

    -- zufällig N Spots aktivieren
    local all = Db.query('SELECT id, label FROM deal_spots') or {}
    local chosen = {}
    for _ = 1, math.min(activeCount, #all) do
        local idx
        repeat idx = math.random(#all) until not chosen[idx]
        chosen[idx] = true
        Db.update('UPDATE deal_spots SET active = 1 WHERE id = ?', { all[idx].id })
    end
    loadSpots()

    local labels = {}
    for idx in pairs(chosen) do labels[#labels + 1] = all[idx].label end
    return labels
end

exports('RotateDealSpots', rotateSpots)
