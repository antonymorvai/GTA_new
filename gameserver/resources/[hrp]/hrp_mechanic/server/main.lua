--[[
    hrp_mechanic – Reparatur (kein Auto-Heal: Fahrzeuge werden NUR hier
    repariert) und generisches Rechnungssystem Spieler-zu-Spieler.

    Rechnung: Mechaniker stellt /bill, Kunde bestätigt /paybill —
    money.transfer(invoice.payment). Tuning-Deckel gegen Abzock-Rechnungen.
    Werkstatt-Zonen, Teile-Verbrauch und Tuning folgen in Phase 4.
]]

local Db = {}
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2WERKSTATT' or '^1WERKSTATT', msg } })
end

local function isMechanic(src)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return nil end
    local job = Jobs:GetJob(ident.characterId)
    if not job or job.name ~= 'mechanic' or job.on_duty ~= 1 then return nil end
    return ident
end

-- /repair — repariert das nächste Fahrzeug (Mechaniker im Dienst)
RegisterCommand('repair', function(src)
    if src == 0 then return end
    local ident = isMechanic(src)
    if not ident then return reply(src, false, 'Nur Mechaniker im Dienst.') end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        -- Fahrzeug in der Nähe suchen (5 m)
        local pos = GetEntityCoords(ped)
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - pos) < 5.0 then vehicle = veh break end
        end
    end
    if vehicle == 0 then return reply(src, false, 'Kein Fahrzeug in der Nähe.') end

    local plate = GetVehicleNumberPlateText(vehicle)
    local engineBefore = GetVehicleEngineHealth(vehicle)

    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    -- Persistenten Zustand aktualisieren, falls es ein Spielerfahrzeug ist
    Db.update('UPDATE vehicles SET engine_health = 1000, body_health = 1000 WHERE plate = ?', { plate })

    Core:Log(src, 'vehicle.repair', {
        target = { kind = 'vehicle', id = plate or 'unknown' },
        payload = { plate = plate, mechanicCharacterId = ident.characterId,
                    engineBefore = engineBefore, engineAfter = 1000.0 },
    })
    reply(src, true, ('Fahrzeug %s repariert. Rechnung stellen mit /bill.'):format(plate or ''))
end, false)

-- /service — Wartung: setzt das Verschleiß-Intervall zurück (Rechnung via /bill)
RegisterCommand('service', function(src)
    if src == 0 then return end
    local ident = isMechanic(src)
    if not ident then return reply(src, false, 'Nur Mechaniker im Dienst.') end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        local pos = GetEntityCoords(ped)
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - pos) < 5.0 then vehicle = veh break end
        end
    end
    if vehicle == 0 then return reply(src, false, 'Kein Fahrzeug in der Nähe.') end

    local plate = GetVehicleNumberPlateText(vehicle)
    local ok = pcall(function() return exports.hrp_vehicles:MarkServiced(plate) end)
    if not ok then return reply(src, false, 'Dieses Fahrzeug ist nicht registriert.') end

    Core:Log(src, 'vehicle.service', {
        target = { kind = 'vehicle', id = plate or 'unknown' },
        payload = { plate = plate, mechanicCharacterId = ident.characterId },
    })
    reply(src, true, ('Wartung an %s durchgeführt — Verschleiß-Intervall zurückgesetzt.'):format(plate or ''))
end, false)

-- /tune <0-3> — Motor-Tuning-Stufe (persistiert; wirkt über Entity-State)
RegisterCommand('tune', function(src, args)
    if src == 0 then return end
    local ident = isMechanic(src)
    if not ident then return reply(src, false, 'Nur Mechaniker im Dienst.') end
    local stage = tonumber(args[1])
    if not stage or stage < 0 or stage > 3 then return reply(src, false, 'Nutzung: /tune <0-3>') end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        local pos = GetEntityCoords(ped)
        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - pos) < 5.0 then vehicle = veh break end
        end
    end
    if vehicle == 0 then return reply(src, false, 'Kein Fahrzeug in der Nähe.') end

    local plate = GetVehicleNumberPlateText(vehicle)
    local before = Db.single('SELECT tune_stage FROM vehicles WHERE plate = ?', { plate })
    if not before then return reply(src, false, 'Dieses Fahrzeug ist nicht registriert.') end

    Db.update('UPDATE vehicles SET tune_stage = ? WHERE plate = ?', { stage, plate })
    Entity(vehicle).state:set('hrp_tune', stage, true)

    Core:Log(src, 'vehicle.tune', {
        target = { kind = 'vehicle', id = plate or 'unknown' },
        payload = { plate = plate, mechanicCharacterId = ident.characterId,
                    stageBefore = before.tune_stage, stageAfter = stage },
    })
    reply(src, true, ('Tuning-Stufe %d verbaut (%s). Rechnung: /bill.'):format(stage, plate))
end, false)

-- ---------------------------------------------------------------------------
-- Rechnungen
-- ---------------------------------------------------------------------------

-- pendingBills[targetSrc] = {fromCharacterId, fromSrc, amount, note, at}
local pendingBills = {}

-- /bill <serverId> <euro> [notiz...]
RegisterCommand('bill', function(src, args)
    if src == 0 then return end
    local ident = isMechanic(src)
    if not ident then return reply(src, false, 'Nur Mechaniker im Dienst.') end
    local targetSrc, euro = tonumber(args[1]), tonumber(args[2])
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end

    local maxAmount = Core:TuningGet('mechanic.max_bill_cents', 100000000)
    local amount = euro and math.floor(euro * 100) or 0
    if amount < 1 or amount > maxAmount then return reply(src, false, 'Ungültiger Betrag.') end

    pendingBills[targetSrc] = {
        fromCharacterId = ident.characterId, fromSrc = src,
        amount = amount, note = table.concat(args, ' ', 3), at = os.time(),
    }
    reply(src, true, 'Rechnung gestellt — der Kunde muss mit /paybill bestätigen.')
    reply(targetSrc, true, ('Rechnung über %s $ erhalten. Bezahlen: /paybill · Ablehnen: ignorieren.')
        :format(string.format('%.2f', amount / 100)))
end, false)

-- /paybill — Kunde bestätigt und zahlt vom Bankkonto
RegisterCommand('paybill', function(src)
    if src == 0 then return end
    local bill = pendingBills[src]
    if not bill or os.time() - bill.at > 300 then
        pendingBills[src] = nil
        return reply(src, false, 'Keine offene Rechnung (oder abgelaufen).')
    end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end

    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < bill.amount then return reply(src, false, 'Kontostand zu niedrig.') end

    local ok = Core:MoneyTransfer(ident.characterId, 'bank', bill.fromCharacterId, 'bank',
        bill.amount, 'invoice.payment')
    pendingBills[src] = nil
    reply(src, ok, ok and 'Rechnung bezahlt.' or 'Zahlung fehlgeschlagen.')
    if ok and bill.fromSrc then
        reply(bill.fromSrc, true, ('Rechnung über %s $ wurde bezahlt.'):format(string.format('%.2f', bill.amount / 100)))
    end
end, false)

AddEventHandler('playerDropped', function()
    pendingBills[source] = nil
end)
