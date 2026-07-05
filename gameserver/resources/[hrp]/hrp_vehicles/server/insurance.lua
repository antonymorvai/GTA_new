--[[
    KFZ-Versicherung (hrp_vehicles):
    - /insure <kz> <liability|partial|full>: Prämie = Promille des Neupreises
      pro Zahlperiode (Tuning), sofort fällig, dann automatischer Einzug.
      Kein Geld -> Versicherung erlischt (vehicle.insurance_lapsed).
    - Totalschaden (main.lua erkennt zerstörte Fahrzeuge): /claim —
      Vollkasko stellt gegen Selbstbeteiligung wieder her, Teilkasko zahlt
      40 % des Neupreises aus (Fahrzeug bleibt Schrott), Haftpflicht deckt
      nur Dritte. /scrap verschrottet gegen Restwert.
]]

local IDb = {}
function IDb.query(sql, p) return MySQL.query.await(sql, p or {}) end
function IDb.single(sql, p) return MySQL.single.await(sql, p or {}) end
function IDb.update(sql, p) return MySQL.update.await(sql, p or {}) end
function IDb.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local ICore = exports.hrp_core
local ILogger = exports.hrp_logger

local TIERS = {
    liability = { label = 'Haftpflicht', permille = 2 },
    partial   = { label = 'Teilkasko',   permille = 5 },
    full      = { label = 'Vollkasko',   permille = 10 },
}

local function ireply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2VERSICHERUNG' or '^1VERSICHERUNG', msg } })
end

local function ownVehicle(src, plate)
    local ident = ICore:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return nil end
    local veh = IDb.single([[
        SELECT v.*, m.base_price, m.label AS model_label FROM vehicles v
        JOIN vehicle_models m ON m.id = v.model_id
        WHERE v.plate = ? AND v.owner_id = ? AND v.deleted_at IS NULL
    ]], { plate, ident.characterId })
    return veh, ident
end

RegisterCommand('insure', function(src, args)
    if src == 0 then return end
    local plate = args[1] and args[1]:upper():sub(1, 8)
    local tier = args[2] and TIERS[args[2]:lower()]
    if not plate or not tier then
        return ireply(src, false, 'Nutzung: /insure <kennzeichen> <liability|partial|full>')
    end
    local veh, ident = ownVehicle(src, plate)
    if not veh then return ireply(src, false, 'Du bist nicht Halter dieses Fahrzeugs.') end
    if veh.status == 'totaled' then return ireply(src, false, 'Totalschäden sind nicht versicherbar.') end

    local periodHours = ICore:TuningGet('insurance.period_hours', 24)
    local premium = math.max(500, math.floor(veh.base_price * tier.permille / 1000))

    local paid, err = ICore:MoneyDestroy(ident.characterId, 'bank', premium, 'insurance.premium')
    if not paid then
        return ireply(src, false, err == 'insufficient_funds'
            and ('Erste Prämie: %s $ (Bank) — nicht gedeckt.'):format(string.format('%.2f', premium / 100))
            or 'Zahlung fehlgeschlagen.')
    end

    IDb.update([[
        INSERT INTO vehicle_insurance (vehicle_id, tier, premium, next_due_at, active)
        VALUES (?, ?, ?, DATE_ADD(NOW(3), INTERVAL ? HOUR), 1)
        ON DUPLICATE KEY UPDATE tier = VALUES(tier), premium = VALUES(premium),
            next_due_at = VALUES(next_due_at), active = 1
    ]], { veh.id, args[2]:lower(), premium, periodHours })

    ICore:Log(src, 'vehicle.insured', {
        target = { kind = 'vehicle', id = tostring(veh.id) },
        payload = { vehicleId = veh.id, plate = plate, tier = args[2]:lower(),
                    premium = premium, periodHours = periodHours },
    })
    ireply(src, true, ('%s für %s abgeschlossen: %s $ pro %d h (automatischer Einzug).')
        :format(tier.label, plate, string.format('%.2f', premium / 100), periodHours))
end, false)

-- Prämien-Einzug (stündlich fällige prüfen)
CreateThread(function()
    while true do
        Wait(3600000)
        local periodHours = ICore:TuningGet('insurance.period_hours', 24)
        local due = IDb.query([[
            SELECT vi.*, v.owner_id, v.plate FROM vehicle_insurance vi
            JOIN vehicles v ON v.id = vi.vehicle_id AND v.deleted_at IS NULL
            WHERE vi.active = 1 AND vi.next_due_at <= NOW(3)
        ]]) or {}
        for _, row in ipairs(due) do
            local paid = ICore:MoneyDestroy(row.owner_id, 'bank', row.premium, 'insurance.premium')
            if paid then
                IDb.update('UPDATE vehicle_insurance SET next_due_at = DATE_ADD(NOW(3), INTERVAL ? HOUR) WHERE vehicle_id = ?',
                    { periodHours, row.vehicle_id })
            else
                IDb.update('UPDATE vehicle_insurance SET active = 0 WHERE vehicle_id = ?', { row.vehicle_id })
                ILogger:Log('vehicle.insurance_lapsed', {
                    target = { kind = 'vehicle', id = tostring(row.vehicle_id) },
                    payload = { vehicleId = row.vehicle_id, plate = row.plate, premium = row.premium },
                })
            end
        end
    end
end)

-- Schadensfall
RegisterCommand('claim', function(src, args)
    if src == 0 then return end
    local plate = args[1] and args[1]:upper():sub(1, 8)
    if not plate then return ireply(src, false, 'Nutzung: /claim <kennzeichen>') end
    local veh, ident = ownVehicle(src, plate)
    if not veh then return ireply(src, false, 'Du bist nicht Halter dieses Fahrzeugs.') end
    if veh.status ~= 'totaled' then return ireply(src, false, 'Kein Totalschaden gemeldet.') end

    local insurance = IDb.single(
        'SELECT * FROM vehicle_insurance WHERE vehicle_id = ? AND active = 1', { veh.id })
    if not insurance then return ireply(src, false, 'Keine aktive Versicherung — /scrap für den Restwert.') end

    if insurance.tier == 'full' then
        local deductible = math.floor(veh.base_price * ICore:TuningGet('insurance.deductible_rate', 0.10))
        local paid, err = ICore:MoneyDestroy(ident.characterId, 'bank', deductible, 'insurance.deductible')
        if not paid then
            return ireply(src, false, ('Selbstbeteiligung %s $ (Bank) nicht gedeckt.')
                :format(string.format('%.2f', deductible / 100)))
        end
        IDb.update([[
            UPDATE vehicles SET status = 'ok', engine_health = 1000, body_health = 1000,
                   stored = 1, garage = 'legion' WHERE id = ?
        ]], { veh.id })
        ICore:Log(src, 'vehicle.claim', {
            target = { kind = 'vehicle', id = tostring(veh.id) },
            payload = { vehicleId = veh.id, plate = plate, tier = 'full', deductible = deductible },
        })
        return ireply(src, true, ('Vollkasko reguliert: %s wiederhergestellt (Garage Legion). Selbstbeteiligung %s $.')
            :format(plate, string.format('%.2f', deductible / 100)))
    end

    if insurance.tier == 'partial' then
        local payout = math.floor(veh.base_price * ICore:TuningGet('insurance.partial_payout_rate', 0.40))
        ICore:MoneyCreate(ident.characterId, 'bank', payout, 'insurance.payout')
        IDb.update('UPDATE vehicles SET deleted_at = NOW(3) WHERE id = ?', { veh.id })
        IDb.update('UPDATE vehicle_insurance SET active = 0 WHERE vehicle_id = ?', { veh.id })
        ICore:Log(src, 'vehicle.claim', {
            target = { kind = 'vehicle', id = tostring(veh.id) },
            payload = { vehicleId = veh.id, plate = plate, tier = 'partial', payout = payout },
        })
        return ireply(src, true, ('Teilkasko reguliert: %s $ ausgezahlt — das Wrack geht an die Versicherung.')
            :format(string.format('%.2f', payout / 100)))
    end

    ireply(src, false, 'Haftpflicht deckt nur Schäden Dritter — /scrap für den Restwert.')
end, false)

-- Verschrotten (Restwert)
RegisterCommand('scrap', function(src, args)
    if src == 0 then return end
    local plate = args[1] and args[1]:upper():sub(1, 8)
    if not plate then return ireply(src, false, 'Nutzung: /scrap <kennzeichen>') end
    local veh, ident = ownVehicle(src, plate)
    if not veh then return ireply(src, false, 'Du bist nicht Halter dieses Fahrzeugs.') end
    if veh.status ~= 'totaled' then return ireply(src, false, 'Nur Totalschäden können verschrottet werden.') end

    local scrapValue = math.floor(veh.base_price * ICore:TuningGet('insurance.scrap_rate', 0.05))
    ICore:MoneyCreate(ident.characterId, 'cash', scrapValue, 'system.sell')
    IDb.update('UPDATE vehicles SET deleted_at = NOW(3) WHERE id = ?', { veh.id })
    IDb.update('UPDATE vehicle_insurance SET active = 0 WHERE vehicle_id = ?', { veh.id })

    ICore:Log(src, 'vehicle.scrapped', {
        target = { kind = 'vehicle', id = tostring(veh.id) },
        payload = { vehicleId = veh.id, plate = plate, scrapValue = scrapValue },
    })
    ireply(src, true, ('%s verschrottet — Restwert %s $ bar.'):format(plate, string.format('%.2f', scrapValue / 100)))
end, false)
