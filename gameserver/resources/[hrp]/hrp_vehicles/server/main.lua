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
    if veh.stored ~= 1 then return reply(src, false, 'Das Fahrzeug ist nicht in der Garage.') end
    if byPlate[veh.plate] then return reply(src, false, 'Das Fahrzeug ist bereits draußen.') end

    local s = garage.spawn
    local entity = CreateVehicleServerSetter(joaat(veh.model), 'automobile', s.x, s.y, s.z, s.w)
    if not entity or entity == 0 then return reply(src, false, 'Ausparken fehlgeschlagen.') end
    SetVehicleNumberPlateText(entity, veh.plate)

    Db.update('UPDATE vehicles SET stored = 0 WHERE id = ?', { veh.id })
    local state = {
        entity = entity, plate = veh.plate, vehicleId = veh.id, ownerId = veh.owner_id,
        fuel = tonumber(veh.fuel_liters), mileage = tonumber(veh.mileage_km),
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
    local atStation = false
    for _, pos in ipairs(FUEL_STATIONS) do
        if nearPos(src, pos, 15.0) then atStation = true break end
    end
    if not atStation then return reply(src, false, 'Du bist an keiner Tankstelle.') end

    local ped = GetPlayerPed(src)
    local vehEntity = GetVehiclePedIsIn(ped, false)
    if vehEntity == 0 then return reply(src, false, 'Du sitzt in keinem Fahrzeug.') end

    for _, state in pairs(active) do
        if state.entity == vehEntity then
            local ident = Core:GetPlayerIdentity(src)
            local liters = math.max(0, state.tank - state.fuel)
            if liters < 1 then return reply(src, false, 'Der Tank ist voll.') end
            local pricePerLiter = Core:TuningGet('vehicles.fuel_price_per_liter', 180) -- Cent
            local cost = math.floor(liters * pricePerLiter)

            local paid, err = Core:MoneyDestroy(ident.characterId, 'cash', cost, 'vehicle.fuel')
            if not paid then
                return reply(src, false, err == 'insufficient_funds' and 'Nicht genug Bargeld.' or 'Zahlung fehlgeschlagen.')
            end

            local before = state.fuel
            state.fuel = state.tank
            Db.update('UPDATE vehicles SET fuel_liters = ? WHERE id = ?', { state.fuel, state.vehicleId })

            Core:Log(src, 'vehicle.refuel', {
                target = { kind = 'vehicle', id = tostring(state.vehicleId) },
                payload = { vehicleId = state.vehicleId, plate = state.plate,
                            liters = liters, cost = cost, fuelBefore = before, fuelAfter = state.fuel },
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
