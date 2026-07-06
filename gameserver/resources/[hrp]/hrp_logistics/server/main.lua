--[[
    hrp_logistics – Lieferketten mit echtem Bedarf:

    Tankstellen haben endliche Bestände (fuel_stations). hrp_vehicles zieht
    beim Tanken vom Stationsbestand ab — LEERE STATION = NIEMAND TANKT.
    Trucker (Job trucker, im Dienst) kaufen an der Raffinerie Kraftstoff zum
    Großhandelspreis, fahren ihn zur Station und verdienen die Liefermarge:
    ein Wirtschaftskreislauf aus echtem Bedarf statt Spawn-Aufträgen.

    Events: logistics.load, logistics.deliver (money-korreliert);
    Stationsbestand wandert in vehicle.refuel-Payloads (hrp_vehicles).
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs
local Logger = exports.hrp_logger

local REFINERY = vector3(2679.0, 1577.4, 24.5)   -- Palomino-Raffinerie

local stations = {}
-- cargo[src] = geladene Liter im aktuellen Truck
local cargo = {}

MySQL.ready(function()
    for _, row in ipairs(Db.query('SELECT * FROM fuel_stations') or {}) do
        stations[row.id] = row
    end
end)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2LOGISTIK' or '^1LOGISTIK', msg } })
end

local function isTrucker(src)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return nil end
    local job = Jobs:GetJob(ident.characterId)
    if not job or job.name ~= 'trucker' or job.on_duty ~= 1 then return nil end
    return ident
end

-- ---------------------------------------------------------------------------
-- Exports für hrp_vehicles (Tanken zieht vom Stationsbestand)
-- ---------------------------------------------------------------------------

function StationNear(x, y, z, radius)
    local pos = vector3(x, y, z)
    for id, s in pairs(stations) do
        if #(pos - vector3(s.pos_x, s.pos_y, s.pos_z)) <= (radius or 15.0) then
            return { id = id, label = s.label, stock = s.stock_l, capacity = s.capacity_l }
        end
    end
    return nil
end

function ConsumeStock(stationId, liters)
    local s = stations[stationId]
    if not s then return 0 end
    local taken = math.min(s.stock_l, math.floor(liters))
    s.stock_l = s.stock_l - taken
    Db.update('UPDATE fuel_stations SET stock_l = ? WHERE id = ?', { s.stock_l, stationId })
    return taken
end

exports('StationNear', StationNear)
exports('ConsumeStock', ConsumeStock)

-- ---------------------------------------------------------------------------
-- Trucker: Laden an der Raffinerie, Liefern an die Station
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:logistics:load', { rate = 0.3, burst = 2 }, function(src)
    local ident = isTrucker(src)
    if not ident then return reply(src, false, 'Nur Trucker im Dienst.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - REFINERY) > 25.0 then
        return reply(src, false, 'Du bist nicht an der Raffinerie (Palomino).')
    end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) == 0 then
        return reply(src, false, 'Du brauchst ein Fahrzeug zum Beladen.')
    end
    if (cargo[src] or 0) > 0 then return reply(src, false, 'Du hast bereits Ladung an Bord.') end

    local capacity = Core:TuningGet('logistics.truck_capacity_l', 3000)
    local wholesale = Core:TuningGet('logistics.wholesale_per_liter', 90)   -- Cent
    local cost = capacity * wholesale
    local correlationId = Logger:NewCorrelationId()

    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < cost then
        return reply(src, false, ('Großhandels-Einkauf kostet %s $ (Bank) — Kontostand zu niedrig.')
            :format(string.format('%.2f', cost / 100)))
    end
    Core:MoneyDestroy(ident.characterId, 'bank', cost, 'system.buy', { correlationId = correlationId })

    cargo[src] = capacity
    Core:Log(src, 'logistics.load', {
        correlationId = correlationId,
        payload = { liters = capacity, wholesaleCost = cost },
    })
    reply(src, true, ('%d L geladen für %s $. Liefere an eine Tankstelle mit Bedarf (/stationen).')
        :format(capacity, string.format('%.2f', cost / 100)))
end)

Core:RegisterSecureEvent('hrp:logistics:deliver', { rate = 0.3, burst = 2 }, function(src)
    local ident = isTrucker(src)
    if not ident then return reply(src, false, 'Nur Trucker im Dienst.') end
    local load = cargo[src] or 0
    if load < 1 then return reply(src, false, 'Keine Ladung an Bord — lade an der Raffinerie (/loadfuel).') end

    local pos = GetEntityCoords(GetPlayerPed(src))
    local station = StationNear(pos.x, pos.y, pos.z, 25.0)
    if not station then return reply(src, false, 'Keine Tankstelle in der Nähe.') end

    local s = stations[station.id]
    local space = s.capacity_l - s.stock_l
    if space < 1 then return reply(src, false, ('%s ist voll — such eine Station mit Bedarf.'):format(s.label)) end

    local delivered = math.min(load, space)
    s.stock_l = s.stock_l + delivered
    cargo[src] = load - delivered
    Db.update('UPDATE fuel_stations SET stock_l = ? WHERE id = ?', { s.stock_l, station.id })

    -- Liefervergütung: Marge über dem Großhandel + Tages-Sättigung
    local payPerLiter = Core:TuningGet('logistics.delivery_pay_per_liter', 130)   -- Cent
    local pay = delivered * payPerLiter
    local factor
    pay, factor = Core:EarningsApply(ident.characterId, 'logistics', pay)
    local correlationId = Logger:NewCorrelationId()
    Core:MoneyCreate(ident.characterId, 'bank', pay, 'logistics.payment', { correlationId = correlationId })

    Core:Log(src, 'logistics.deliver', {
        target = { kind = 'fuel_station', id = tostring(station.id) },
        correlationId = correlationId,
        payload = { stationId = station.id, station = s.label, liters = delivered,
                    pay = pay, stationStockAfter = s.stock_l },
    })

    pcall(function() exports.hrp_skills:AddXp(ident.characterId, 'driving', 20, src) end)
    reply(src, true, ('%d L geliefert an %s: %s $ Vergütung.%s')
        :format(delivered, s.label, string.format('%.2f', pay / 100),
                cargo[src] > 0 and (' Restladung: ' .. cargo[src] .. ' L.') or ''))
end)

-- Bedarfs-Übersicht (auch für Nicht-Trucker sichtbar — Markt-Transparenz)
Core:RegisterSecureEvent('hrp:logistics:stations', { rate = 0.5, burst = 2 }, function(src)
    for _, s in pairs(stations) do
        local pct = math.floor(s.stock_l / s.capacity_l * 100)
        reply(src, pct > 15, ('%s: %d/%d L (%d%%)%s')
            :format(s.label, s.stock_l, s.capacity_l, pct, pct <= 15 and ' — DRINGEND' or ''))
    end
end)

AddEventHandler('playerDropped', function()
    cargo[source] = nil
end)
