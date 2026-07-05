--[[
    hrp_director – World Director: erzeugt gewichtete Zufallsereignisse,
    Frequenz und Gewichte live über das Tuning steuerbar, jedes Ereignis
    als director.event geloggt.

    Registrierte Ereignisse (Phase 4):
    - dealspot_rotate: Deal-Spots rotieren (Kriminalität verlagert sich)
    - resource_boom:   Ressourcen-Boom an zufälligem Pool (z. B. Fischschwarm)
    - traffic_accident: Unfall-Wrack an zufälliger Stelle + Dispatch an
      Polizei/Rettung (RP-Einsatz ohne Admin-Eingriff)

    Weitere Ereignisse (Brände, Stromausfälle, Geldtransporte, Seuchen)
    registrieren sich in späteren Ausbaustufen über dieselbe Registry.
]]

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local ACCIDENT_SPOTS = {
    { pos = vector4(-531.9, -854.9, 29.3, 90.0),  label = 'Vespucci Boulevard' },
    { pos = vector4(1114.5, -774.5, 57.6, 340.0), label = 'Mirror Park Drive' },
    { pos = vector4(214.5, -1400.5, 30.6, 140.0), label = 'Strawberry Avenue' },
    { pos = vector4(1704.9, 3596.5, 35.5, 20.0),  label = 'Sandy Shores Highway' },
}
local WRECK_MODELS = { 'asea', 'blista', 'sadler' }

local function notifyDuty(jobNames, message)
    local Jobs = exports.hrp_jobs
    for _, srcStr in ipairs(GetPlayers()) do
        local src = tonumber(srcStr)
        local ident = Core:GetPlayerIdentity(src)
        if ident and ident.characterId then
            local ok, job = pcall(function() return Jobs:GetJob(ident.characterId) end)
            if ok and job and jobNames[job.name] and job.on_duty == 1 then
                TriggerClientEvent('chat:addMessage', src, { args = { '^4DISPATCH', message } })
            end
        end
    end
end

-- Ereignis-Registry: name -> {defaultWeight, run() -> payload|nil}
local registry = {
    dealspot_rotate = {
        defaultWeight = 30,
        run = function()
            local ok, labels = pcall(function() return exports.hrp_drugs:RotateDealSpots() end)
            if not ok then return nil end
            return { rotatedTo = labels }
        end,
    },
    resource_boom = {
        defaultWeight = 25,
        run = function()
            local ok, label = pcall(function() return exports.hrp_resources:Boom() end)
            if not ok or not label then return nil end
            TriggerClientEvent('chat:addMessage', -1, {
                args = { '^3NEWS', ('Gerüchte über reiche Vorkommen: %s'):format(label) },
            })
            return { pool = label }
        end,
    },
    traffic_accident = {
        defaultWeight = 20,
        run = function()
            local spot = ACCIDENT_SPOTS[math.random(#ACCIDENT_SPOTS)]
            local model = WRECK_MODELS[math.random(#WRECK_MODELS)]
            local veh = CreateVehicleServerSetter(joaat(model), 'automobile',
                spot.pos.x, spot.pos.y, spot.pos.z, spot.pos.w)
            if veh and veh ~= 0 then
                SetVehicleEngineHealth(veh, 50.0)
                SetVehicleBodyHealth(veh, 150.0)
                -- Wrack nach 20 Minuten aufräumen
                SetTimeout(20 * 60000, function()
                    if DoesEntityExist(veh) then DeleteEntity(veh) end
                end)
            end
            notifyDuty({ police = true, ems = true },
                ('Verkehrsunfall gemeldet: %s'):format(spot.label))
            return { location = spot.label, model = model }
        end,
    },
}

-- Geldtransport: gepanzerter Transporter auf zufälliger Route — Überfall
-- möglich, wenn der Motor tot ist (/robtransport), massive Spuren garantiert.
local activeTransport = nil

registry.money_transport = {
    defaultWeight = 12,
    run = function()
        if activeTransport and DoesEntityExist(activeTransport.entity) then return nil end
        local spot = ACCIDENT_SPOTS[math.random(#ACCIDENT_SPOTS)]
        local veh = CreateVehicleServerSetter(joaat('stockade'), 'automobile',
            spot.pos.x, spot.pos.y, spot.pos.z, spot.pos.w)
        if not veh or veh == 0 then return nil end
        activeTransport = { entity = veh, looted = false, spawnedAt = os.time() }
        Entity(veh).state:set('hrp_transport', true, true)

        TriggerClientEvent('chat:addMessage', -1, {
            args = { '^3NEWS', ('Ein Geldtransport ist unterwegs — zuletzt gesehen: %s.'):format(spot.label) },
        })
        notifyDuty({ police = true }, ('Geldtransport-Begleitschutz angefordert: %s'):format(spot.label))

        SetTimeout(15 * 60000, function()
            if activeTransport and DoesEntityExist(activeTransport.entity) then
                DeleteEntity(activeTransport.entity)
            end
            activeTransport = nil
        end)
        return { location = spot.label }
    end,
}

RegisterCommand('robtransport', function(src)
    if src == 0 then return end
    local Core2 = exports.hrp_core
    local ident = Core2:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    if not activeTransport or not DoesEntityExist(activeTransport.entity) or activeTransport.looted then
        return TriggerClientEvent('chat:addMessage', src, { args = { '^1RAUB', 'Kein aufgebrochener Transport in der Nähe.' } })
    end
    local tvPos = GetEntityCoords(activeTransport.entity)
    if #(GetEntityCoords(GetPlayerPed(src)) - tvPos) > 8.0 then
        return TriggerClientEvent('chat:addMessage', src, { args = { '^1RAUB', 'Du bist zu weit weg.' } })
    end
    if GetVehicleEngineHealth(activeTransport.entity) > 100.0 then
        return TriggerClientEvent('chat:addMessage', src, { args = { '^1RAUB', 'Der Transporter fährt noch — erst stoppen.' } })
    end

    activeTransport.looted = true
    local loot = Core:TuningGet('director.transport_loot', 250000)
        + math.random(0, Core:TuningGet('director.transport_loot_variance', 100000))
    Core:MoneyCreate(ident.characterId, 'cash', loot, 'heist.loot')

    Core:Log(src, 'crime.trace', {
        payload = { crime = 'transport_robbery', hint = 'Geldtransport überfallen',
                    suspectCharacterId = ident.characterId,
                    pos = { x = tvPos.x, y = tvPos.y, z = tvPos.z } },
    })
    notifyDuty({ police = true }, 'GELDTRANSPORT ÜBERFALLEN — alle Einheiten!')
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2RAUB', ('Du schnappst dir %s $ — und die halbe Stadt hat es gesehen.')
            :format(string.format('%.2f', loot / 100)) },
    })
end, false)

local function pickWeighted()
    local total, weights = 0, {}
    for name, def in pairs(registry) do
        local w = Core:TuningGet('director.weight_' .. name, def.defaultWeight)
        if w > 0 then
            weights[name] = w
            total = total + w
        end
    end
    if total == 0 then return nil end
    local roll = math.random() * total
    local acc = 0
    for name, w in pairs(weights) do
        acc = acc + w
        if roll <= acc then return name end
    end
    return nil
end

CreateThread(function()
    while true do
        local minutes = Core:TuningGet('director.tick_minutes', 20)
        Wait(math.max(1, minutes) * 60000)
        if Core:TuningGet('director.enabled', true) ~= true then goto continue end

        local name = pickWeighted()
        if name then
            local ok, payload = pcall(registry[name].run)
            Logger:Log('director.event', {
                payload = {
                    event = name,
                    success = ok and payload ~= nil,
                    detail = ok and payload or tostring(payload),
                },
            })
        end
        ::continue::
    end
end)

-- Manueller Trigger für Tests/ACP (Konsole): hrp_director_fire <event>
RegisterCommand('hrp_director_fire', function(src, args)
    if src ~= 0 then return end
    local def = args[1] and registry[args[1]]
    if not def then
        local names = {}
        for n in pairs(registry) do names[#names + 1] = n end
        print('Usage: hrp_director_fire <' .. table.concat(names, '|') .. '>')
        return
    end
    local ok, payload = pcall(def.run)
    Logger:Log('director.event', {
        payload = { event = args[1], success = ok and payload ~= nil,
                    detail = ok and payload or tostring(payload), manual = true },
    })
    print('OK: ' .. args[1])
end, true)
