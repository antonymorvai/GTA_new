--[[
    hrp_vehicles – server-autoritative Fahrzeug-Basis:
    Kauf beim Händler, Garagen (ausparken/einparken), Schlüsselverwaltung,
    Kraftstoffverbrauch + Kilometerstand (server-seitig gemessen), Persistenz.

    Events: vehicle.buy (money-korreliert), vehicle.spawn, vehicle.store,
    vehicle.enter/exit, vehicle.key_grant, vehicle.refuel, vehicle.save.
    Verschleiß/TÜV/Versicherung erweitern das Modul in Phase 3+.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

-- Orte (Basis-Set, ab Phase 4 als Map-Daten pflegbar)
local DEALER = vector3(-56.6, -1096.8, 26.4)          -- PDM
local GARAGES = {
    legion = { pos = vector3(215.9, -810.1, 30.7), spawn = vector4(228.8, -800.1, 30.6, 157.0) },
    paleto = { pos = vector3(-112.0, 6425.9, 31.4), spawn = vector4(-106.8, 6417.9, 31.5, 45.0) },
}
local FUEL_STATIONS = {
    vector3(49.4, 2778.8, 58.0), vector3(263.9, 2606.5, 44.9),
    vector3(-70.2, -1761.8, 29.5), vector3(265.6, -1261.3, 29.3),
    vector3(-524.0, -1211.1, 18.2), vector3(1208.9, 2660.2, 37.9),
}

-- Aktive (ausgeparkte) Fahrzeuge: byId[vehicleId] = {entity, plate, ownerId, fuel, mileage, lastCoords}
local active = {}
local byPlate = {}

-- Blitzer (DB-Daten) + Auslöse-Cooldown pro Fahrzeug
local cameras = {}
local cameraCooldown = {}
MySQL.ready(function()
    cameras = Db.query('SELECT * FROM speed_cameras WHERE active = 1') or {}
end)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2FAHRZEUG' or '^1FAHRZEUG', msg } })
end

local function nearPos(src, pos, radius)
    return #(GetEntityCoords(GetPlayerPed(src)) - pos) <= radius
end

local function generatePlate()
    local letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    for _ = 1, 20 do
        local plate = letters:sub(math.random(1, 24), math.random(1, 24))
            .. letters:sub(math.random(1, 24), math.random(1, 24))
            .. string.format('%05d', math.random(0, 99999)) .. ' '
        plate = plate:sub(1, 8)
        if not Db.scalar('SELECT 1 FROM vehicles WHERE plate = ?', { plate }) then
            return plate
        end
    end
    return nil
end

local function hasKey(characterId, vehicleRow)
    if vehicleRow.owner_id == characterId then return true end
    return Db.scalar('SELECT 1 FROM vehicle_keys WHERE vehicle_id = ? AND character_id = ?',
        { vehicleRow.id, characterId }) ~= nil
end

-- ---------------------------------------------------------------------------
-- Kauf
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:buy', {
    rate = 0.5, burst = 2,
    schema = { { type = 'string', maxLen = 64, pattern = '^[%w_]+$' } },
}, function(src, model)
    if not nearPos(src, DEALER, 15.0) then return reply(src, false, 'Du bist nicht beim Fahrzeughändler.') end

    local modelRow = Db.single('SELECT * FROM vehicle_models WHERE model = ?', { model })
    if not modelRow then return reply(src, false, 'Dieses Modell wird nicht angeboten.') end
    if modelRow.dealer_stock < 1 then return reply(src, false, 'Ausverkauft — Import-Wartelisten folgen.') end

    local ident = Core:GetPlayerIdentity(src)
    local correlationId = Logger:NewCorrelationId()

    -- Bezahlung vom Bankkonto (Fahrzeuge sind Kartenzahlung)
    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < modelRow.base_price then return reply(src, false, 'Kontostand zu niedrig.') end
    local paid = Core:MoneyDestroy(ident.characterId, 'bank', modelRow.base_price, 'vehicle.buy',
        { correlationId = correlationId })
    if not paid then return reply(src, false, 'Zahlung fehlgeschlagen.') end

    local plate = generatePlate()
    if not plate then
        Core:MoneyCreate(ident.characterId, 'bank', modelRow.base_price, 'system.sell', { correlationId = correlationId })
        return reply(src, false, 'Zulassung fehlgeschlagen.')
    end

    Core:TreasuryCredit(modelRow.base_price, 'vehicle.buy', { correlationId = correlationId })

    local vehicleId = Db.insert([[
        INSERT INTO vehicles (plate, model_id, owner_id, fuel_liters, garage)
        VALUES (?, ?, ?, ?, 'legion')
    ]], { plate, modelRow.id, ident.characterId, modelRow.tank_liters })
    Db.update('UPDATE vehicle_models SET dealer_stock = dealer_stock - 1 WHERE id = ?', { modelRow.id })

    Core:Log(src, 'vehicle.buy', {
        target = { kind = 'vehicle', id = tostring(vehicleId) },
        correlationId = correlationId,
        payload = { vehicleId = vehicleId, plate = plate, model = model,
                    price = modelRow.base_price, ownerId = ident.characterId },
    })
    reply(src, true, ('Gekauft: %s · Kennzeichen %s · steht in der Garage Legion.'):format(modelRow.label, plate))
end)

-- ---------------------------------------------------------------------------
-- Garage: ausparken / einparken
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:garageOut', {
    rate = 0.5, burst = 2,
    schema = { { type = 'string', maxLen = 8 } },
}, function(src, plate)
    local ident = Core:GetPlayerIdentity(src)
    local garageName, garage
    for name, g in pairs(GARAGES) do
        if nearPos(src, g.pos, 10.0) then garageName, garage = name, g break end
    end
    if not garage then return reply(src, false, 'Du bist an keiner Garage.') end

    local veh = Db.single([[
        SELECT v.*, m.model, m.label FROM vehicles v
        JOIN vehicle_models m ON m.id = v.model_id
        WHERE v.plate = ? AND v.deleted_at IS NULL
    ]], { plate })
    if not veh then return reply(src, false, 'Unbekanntes Kennzeichen.') end
    if not hasKey(ident.characterId, veh) then return reply(src, false, 'Du hast keinen Schlüssel für dieses Fahrzeug.') end
    if veh.status == 'totaled' then
        return reply(src, false, 'TOTALSCHADEN — reguliere über /claim (Versicherung) oder /scrap (Restwert).')
    end
    if veh.stored ~= 1 then return reply(src, false, 'Das Fahrzeug ist nicht in der Garage.') end
    if byPlate[veh.plate] then return reply(src, false, 'Das Fahrzeug ist bereits draußen.') end

    local s = garage.spawn
    local entity = CreateVehicleServerSetter(joaat(veh.model), 'automobile', s.x, s.y, s.z, s.w)
    if not entity or entity == 0 then return reply(src, false, 'Ausparken fehlgeschlagen.') end
    SetVehicleNumberPlateText(entity, veh.plate)
    Entity(entity).state:set('hrp_tune', veh.tune_stage or 0, true)

    Db.update('UPDATE vehicles SET stored = 0 WHERE id = ?', { veh.id })
    local state = {
        entity = entity, plate = veh.plate, vehicleId = veh.id, ownerId = veh.owner_id,
        fuel = tonumber(veh.fuel_liters), mileage = tonumber(veh.mileage_km),
        lastService = tonumber(veh.last_service_km) or 0,
        consumption = tonumber(Db.scalar('SELECT consumption_per_100km FROM vehicle_models WHERE id = ?', { veh.model_id })),
        tank = tonumber(Db.scalar('SELECT tank_liters FROM vehicle_models WHERE id = ?', { veh.model_id })),
        lastCoords = vector3(s.x, s.y, s.z),
    }
    active[veh.id] = state
    byPlate[veh.plate] = state

    Core:Log(src, 'vehicle.spawn', {
        target = { kind = 'vehicle', id = tostring(veh.id) },
        payload = { vehicleId = veh.id, plate = veh.plate, garage = garageName },
    })
    reply(src, true, ('%s ausgeparkt (Tank: %.0f L, %.0f km).'):format(veh.label, state.fuel, state.mileage))
end)

local function storeVehicle(src, state, garageName)
    local coords = GetEntityCoords(state.entity)
    Db.update([[
        UPDATE vehicles SET stored = 1, garage = ?, fuel_liters = ?, mileage_km = ?,
               engine_health = ?, body_health = ?, position = NULL
        WHERE id = ?
    ]], { garageName, state.fuel, state.mileage,
          GetVehicleEngineHealth and GetVehicleEngineHealth(state.entity) or 1000.0,
          GetVehicleBodyHealth and GetVehicleBodyHealth(state.entity) or 1000.0,
          state.vehicleId })
    DeleteEntity(state.entity)
    active[state.vehicleId] = nil
    byPlate[state.plate] = nil

    Core:Log(src, 'vehicle.store', {
        target = { kind = 'vehicle', id = tostring(state.vehicleId) },
        payload = { vehicleId = state.vehicleId, plate = state.plate, garage = garageName,
                    fuel = state.fuel, mileageKm = state.mileage },
    })
end

Core:RegisterSecureEvent('hrp:vehicles:garageIn', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local garageName, garage
    for name, g in pairs(GARAGES) do
        if nearPos(src, g.pos, 15.0) then garageName, garage = name, g break end
    end
    if not garage then return reply(src, false, 'Du bist an keiner Garage.') end

    local ped = GetPlayerPed(src)
    local vehEntity = GetVehiclePedIsIn(ped, false)
    if vehEntity == 0 then return reply(src, false, 'Du sitzt in keinem Fahrzeug.') end

    for _, state in pairs(active) do
        if state.entity == vehEntity then
            local vehRow = Db.single('SELECT * FROM vehicles WHERE id = ?', { state.vehicleId })
            if not hasKey(ident.characterId, vehRow) then
                return reply(src, false, 'Du hast keinen Schlüssel für dieses Fahrzeug.')
            end
            storeVehicle(src, state, garageName)
            return reply(src, true, 'Fahrzeug eingeparkt.')
        end
    end
    reply(src, false, 'Dieses Fahrzeug gehört nicht in eine Spieler-Garage.')
end)

-- ---------------------------------------------------------------------------
-- Schlüssel
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:giveKey', {
    rate = 0.5, burst = 2,
    schema = {
        { type = 'number', integer = true, min = 1 },   -- targetServerId
        { type = 'string', maxLen = 8 },                 -- plate
    },
}, function(src, targetSrc, plate)
    local ident = Core:GetPlayerIdentity(src)
    local target = Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 3.0 then
        return reply(src, false, 'Der Spieler ist zu weit weg.')
    end

    local veh = Db.single('SELECT * FROM vehicles WHERE plate = ? AND deleted_at IS NULL', { plate })
    if not veh or veh.owner_id ~= ident.characterId then
        return reply(src, false, 'Du bist nicht der Halter dieses Fahrzeugs.')
    end

    Db.update('INSERT IGNORE INTO vehicle_keys (vehicle_id, character_id, granted_by) VALUES (?, ?, ?)',
        { veh.id, target.characterId, ident.characterId })

    Core:Log(src, 'vehicle.key_grant', {
        target = { kind = 'vehicle', id = tostring(veh.id) },
        payload = { vehicleId = veh.id, plate = plate,
                    fromCharacterId = ident.characterId, toCharacterId = target.characterId },
    })
    reply(src, true, 'Schlüssel übergeben.')
    reply(targetSrc, true, ('Du hast einen Schlüssel erhalten: %s'):format(plate))
end)

-- ---------------------------------------------------------------------------
-- Tanken
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:refuel', { rate = 0.5, burst = 2 }, function(src)
    -- Station mit ECHTEM Bestand (hrp_logistics); Fallback: Koordinaten-Liste
    local playerPos = GetEntityCoords(GetPlayerPed(src))
    local station
    local hasLogistics = pcall(function()
        station = exports.hrp_logistics:StationNear(playerPos.x, playerPos.y, playerPos.z, 15.0)
    end)
    if not hasLogistics then
        for _, pos in ipairs(FUEL_STATIONS) do
            if nearPos(src, pos, 15.0) then station = { id = nil, stock = 999999 } break end
        end
    end
    if not station then return reply(src, false, 'Du bist an keiner Tankstelle.') end

    local ped = GetPlayerPed(src)
    local vehEntity = GetVehiclePedIsIn(ped, false)
    if vehEntity == 0 then return reply(src, false, 'Du sitzt in keinem Fahrzeug.') end

    for _, state in pairs(active) do
        if state.entity == vehEntity then
            local ident = Core:GetPlayerIdentity(src)
            local liters = math.max(0, state.tank - state.fuel)
            if liters < 1 then return reply(src, false, 'Der Tank ist voll.') end

            -- Lieferketten-Realität: leere Station verkauft nichts
            liters = math.min(liters, station.stock or 0)
            if liters < 1 then
                return reply(src, false, ('%s ist LEER — ein Trucker muss liefern (/stationen).')
                    :format(station.label or 'Diese Tankstelle'))
            end

            local pricePerLiter = Core:TuningGet('vehicles.fuel_price_per_liter', 180) -- Cent
            local cost = math.floor(liters * pricePerLiter)

            local paid, err = Core:MoneyDestroy(ident.characterId, 'cash', cost, 'vehicle.fuel')
            if not paid then
                return reply(src, false, err == 'insufficient_funds' and 'Nicht genug Bargeld.' or 'Zahlung fehlgeschlagen.')
            end

            local before = state.fuel
            state.fuel = math.min(state.tank, state.fuel + liters)
            Db.update('UPDATE vehicles SET fuel_liters = ? WHERE id = ?', { state.fuel, state.vehicleId })

            -- Stationsbestand abbuchen (Lieferketten-Kopplung)
            if station.id then
                pcall(function() exports.hrp_logistics:ConsumeStock(station.id, liters) end)
            end

            Core:Log(src, 'vehicle.refuel', {
                target = { kind = 'vehicle', id = tostring(state.vehicleId) },
                payload = { vehicleId = state.vehicleId, plate = state.plate,
                            liters = liters, cost = cost, fuelBefore = before, fuelAfter = state.fuel,
                            stationId = station.id, station = station.label },
            })
            return reply(src, true, ('%.1f L getankt für %s $.'):format(liters, string.format('%.2f', cost / 100)))
        end
    end
    reply(src, false, 'Dieses Fahrzeug kann hier nicht betankt werden.')
end)

-- ---------------------------------------------------------------------------
-- Ein-/Aussteigen (Client meldet, Server validiert + loggt)
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:seat', {
    rate = 4, burst = 8,
    schema = { { type = 'boolean' } },
}, function(src, entered)
    local ped = GetPlayerPed(src)
    local vehEntity = GetVehiclePedIsIn(ped, not entered)  -- beim Aussteigen: letztes Fahrzeug
    if vehEntity == 0 then return end
    local plate = GetVehicleNumberPlateText(vehEntity)

    Core:Log(src, entered and 'vehicle.enter' or 'vehicle.exit', {
        target = { kind = 'vehicle', id = plate or 'unknown' },
        payload = { plate = plate, seat = GetPedInVehicleSeat(vehEntity, -1) == ped and 'driver' or 'passenger' },
    })
end)

-- ---------------------------------------------------------------------------
-- Verbrauch/Kilometer-Tick + periodischer Save
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(10000)
        -- Totalschaden-Erkennung: zerstörte Fahrzeuge sind SCHROTT (kein Auto-Heal)
        local totaled = {}
        for id, state in pairs(active) do
            if DoesEntityExist(state.entity) and IsEntityDead(state.entity) then
                totaled[#totaled + 1] = { id = id, state = state }
            end
        end
        for _, entry in ipairs(totaled) do
            local state = entry.state
            local c = GetEntityCoords(state.entity)
            Db.update([[
                UPDATE vehicles SET status = 'totaled', stored = 1, fuel_liters = ?,
                       mileage_km = ?, engine_health = 0, body_health = 0, position = NULL
                WHERE id = ?
            ]], { state.fuel, state.mileage, state.vehicleId })
            exports.hrp_logger:Log('vehicle.total_loss', {
                target = { kind = 'vehicle', id = tostring(state.vehicleId) },
                payload = { vehicleId = state.vehicleId, plate = state.plate,
                            pos = { x = c.x, y = c.y, z = c.z }, mileageKm = state.mileage },
            })
            SetTimeout(30000, function()
                if DoesEntityExist(state.entity) then DeleteEntity(state.entity) end
            end)
            active[entry.id] = nil
            byPlate[state.plate] = nil
        end

        for _, state in pairs(active) do
            if DoesEntityExist(state.entity) then
                local coords = GetEntityCoords(state.entity)
                local meters = #(coords - state.lastCoords)
                state.lastCoords = coords
                if meters > 1.0 and meters < 2000.0 then    -- Teleport-Ausreißer ignorieren
                    local km = meters / 1000.0
                    state.mileage = state.mileage + km
                    state.fuel = math.max(0, state.fuel - km * state.consumption / 100.0)
                    if state.fuel <= 0 then
                        -- Motor aus bei leerem Tank (server-autoritativ)
                        SetVehicleEngineOn(state.entity, false, true, true)
                    end

                    -- Verschleiß: Motor altert pro km; jenseits des Wartungs-
                    -- intervalls doppelt so schnell (kein Auto-Heal — nur die
                    -- Werkstatt repariert, /service setzt das Intervall zurück)
                    local wearPerKm = Core:TuningGet('vehicles.wear_per_km', 0.35)
                    local interval = Core:TuningGet('vehicles.service_interval_km', 500.0)
                    local overdue = (state.mileage - state.lastService) > interval
                    local wear = km * wearPerKm * (overdue and 2.0 or 1.0)
                    local engine = GetVehicleEngineHealth(state.entity)
                    if engine > 150.0 then
                        SetVehicleEngineHealth(state.entity, math.max(150.0, engine - wear))
                    end
                end
                -- Tankstand an den Fahrer pushen (HUD) + Blitzer-Prüfung
                local driverPed = GetPedInVehicleSeat(state.entity, -1)
                if driverPed and driverPed ~= 0 then
                    local driverSrc
                    for _, srcStr in ipairs(GetPlayers()) do
                        local pSrc = tonumber(srcStr)
                        if GetPlayerPed(pSrc) == driverPed then driverSrc = pSrc break end
                    end
                    if driverSrc then
                        TriggerClientEvent('hrp:vehicles:fuel', driverSrc, state.fuel, state.tank)

                        -- Blitzer: Geschwindigkeit über das 10-s-Fenster gemittelt
                        local kmh = (meters / 10.0) * 3.6
                        local tolerance = Core:TuningGet('vehicles.camera_tolerance_kmh', 10)
                        for _, cam in ipairs(cameras) do
                            local key = state.vehicleId .. ':' .. cam.id
                            local onCooldown = cameraCooldown[key] and GetGameTimer() - cameraCooldown[key] < 120000
                            if not onCooldown
                                and #(coords - vector3(cam.pos_x, cam.pos_y, cam.pos_z)) < 40.0
                                and kmh > cam.limit_kmh + tolerance then
                                cameraCooldown[key] = GetGameTimer()
                                local driver = Core:GetPlayerIdentity(driverSrc)
                                if driver and driver.characterId then
                                    local fineId = nil
                                    pcall(function()
                                        fineId = exports.hrp_justice:IssueSystemFine(driver.characterId, 'StVO-1',
                                            ('Blitzer %s: %d km/h bei %d erlaubt (Kz. %s)')
                                                :format(cam.label, math.floor(kmh), cam.limit_kmh, state.plate))
                                    end)
                                    Core:Log(driverSrc, 'vehicle.speeding', {
                                        target = { kind = 'vehicle', id = tostring(state.vehicleId) },
                                        payload = { plate = state.plate, cameraId = cam.id, camera = cam.label,
                                                    kmh = math.floor(kmh), limitKmh = cam.limit_kmh, fineId = fineId },
                                    })
                                    TriggerClientEvent('chat:addMessage', driverSrc, {
                                        args = { '^1BLITZER', ('Geblitzt: %d km/h bei %d erlaubt (%s). Bußgeld unter /myfines — Einspruch über die Justiz.')
                                            :format(math.floor(kmh), cam.limit_kmh, cam.label) },
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        for _, state in pairs(active) do
            if DoesEntityExist(state.entity) then
                local c = GetEntityCoords(state.entity)
                Db.update([[
                    UPDATE vehicles SET fuel_liters = ?, mileage_km = ?, position = ? WHERE id = ?
                ]], { state.fuel, state.mileage,
                      json.encode({ x = c.x, y = c.y, z = c.z, h = GetEntityHeading(state.entity) }),
                      state.vehicleId })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- KOFFERRAUM: Container 'vehicle_trunk:<kennzeichen>' — Zugriff mit Schlüssel
-- am aktiven Fahrzeug in Reichweite.
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:vehicles:trunk', {
    rate = 1, burst = 4,
    schema = {
        { type = 'string', maxLen = 8, pattern = '^%a+$' },
        { type = 'string', maxLen = 36, pattern = '^[%x%-]+$', optional = true },
    },
}, function(src, action, uuid)
    local ident = Core:GetPlayerIdentity(src)
    local pos = GetEntityCoords(GetPlayerPed(src))

    -- nächstes aktives Fahrzeug mit Schlüssel finden
    local target
    for _, state in pairs(active) do
        if DoesEntityExist(state.entity) and #(GetEntityCoords(state.entity) - pos) < 5.0 then
            local row = Db.single('SELECT * FROM vehicles WHERE id = ?', { state.vehicleId })
            if row and hasKey(ident.characterId, row) then target = state break end
        end
    end
    if not target then return reply(src, false, 'Kein eigenes Fahrzeug in Reichweite (Schlüssel nötig).') end

    local Inv = exports.hrp_inventory
    if action == 'list' then
        local items = Inv:GetContainer('vehicle_trunk', target.plate) or {}
        if #items == 0 then return reply(src, true, 'Der Kofferraum ist leer.') end
        for _, it in ipairs(items) do
            reply(src, true, ('%s · %s x%d'):format(it.uuid:sub(1, 8), it.label, it.quantity))
        end
    elseif action == 'store' and uuid then
        local ok, err = Inv:Move(uuid, { type = 'vehicle_trunk', id = target.plate }, { srcForLog = src })
        reply(src, ok == true, ok and 'Im Kofferraum verstaut.' or ('Fehlgeschlagen: ' .. tostring(err)))
    elseif action == 'take' and uuid then
        local found = false
        for _, it in ipairs(Inv:GetContainer('vehicle_trunk', target.plate) or {}) do
            if it.uuid == uuid then found = true break end
        end
        if not found then return reply(src, false, 'Liegt nicht in diesem Kofferraum.') end
        local ok, err = Inv:Move(uuid, { type = 'character', id = ident.characterId }, { srcForLog = src })
        reply(src, ok == true, ok and 'Entnommen.' or ('Fehlgeschlagen: ' .. tostring(err)))
    end
end)

--- Wartung durchgeführt (hrp_mechanic): Intervall zurücksetzen.
local function markServiced(plate)
    local affected = Db.update(
        'UPDATE vehicles SET last_service_km = mileage_km WHERE plate = ? AND deleted_at IS NULL', { plate })
    if affected == 0 then return false end
    local state = byPlate[plate]
    if state then state.lastService = state.mileage end
    return true
end

exports('MarkServiced', markServiced)

-- Meine Fahrzeuge auflisten
Core:RegisterSecureEvent('hrp:vehicles:list', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local rows = Db.query([[
        SELECT v.plate, v.stored, v.garage, v.fuel_liters, v.mileage_km, m.label
        FROM vehicles v JOIN vehicle_models m ON m.id = v.model_id
        WHERE v.owner_id = ? AND v.deleted_at IS NULL
    ]], { ident.characterId }) or {}
    if #rows == 0 then return reply(src, false, 'Du besitzt keine Fahrzeuge.') end
    for _, v in ipairs(rows) do
        reply(src, true, ('%s · %s · %s · %.0f km · Tank %.0f L')
            :format(v.plate, v.label, v.stored == 1 and ('Garage ' .. v.garage) or 'draußen',
                    v.mileage_km, v.fuel_liters))
    end
end)
