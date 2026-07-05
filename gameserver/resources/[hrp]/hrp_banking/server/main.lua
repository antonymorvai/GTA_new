--[[
    hrp_banking – Kontonummern, Ein-/Auszahlung (nur an Bank/ATM-Standorten,
    server-seitig geprüft), Überweisungen per Kontonummer, Daueraufträge.

    Alle Geldbewegungen laufen über die Core-Geld-API (money.*-Events);
    Kontoauszüge sind damit vollständig aus dem Log-Store generierbar.
    Kredite/Pfändungen folgen in Phase 3 (Justiz-Anbindung).
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end

-- Bank-/ATM-Standorte (Basis-Set; ab Phase 4 als Map-Daten pflegbar)
local LOCATIONS = {
    vector3(150.2, -1040.5, 29.4),    -- Legion Square Bank
    vector3(-1212.9, -330.9, 37.8),   -- Rockford Hills
    vector3(-2962.6, 482.9, 15.7),    -- Great Ocean Hwy
    vector3(1175.0, 2706.6, 38.1),    -- Route 68
    vector3(-112.2, 6469.3, 31.6),    -- Paleto Bay
}

local function isAtBank(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    local radius = Core:TuningGet('banking.location_radius', 10.0)
    for _, loc in ipairs(LOCATIONS) do
        if #(pos - loc) <= radius then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Kontonummern
-- ---------------------------------------------------------------------------

local function generateAccountNumber()
    for _ = 1, 20 do
        local number = ('LS%08d'):format(math.random(0, 99999999))
        if not Db.scalar('SELECT 1 FROM bank_details WHERE account_number = ?', { number }) then
            return number
        end
    end
    return nil
end

--- Kontonummer holen (lazy anlegen beim ersten Bankkontakt).
local function getAccountNumber(characterId)
    local existing = Db.scalar('SELECT account_number FROM bank_details WHERE character_id = ?', { characterId })
    if existing then return existing end
    local number = generateAccountNumber()
    if not number then return nil end
    Db.insert('INSERT INTO bank_details (character_id, account_number) VALUES (?, ?)', { characterId, number })
    return number
end

exports('GetAccountNumber', getAccountNumber)

-- ---------------------------------------------------------------------------
-- Ein-/Auszahlung/Überweisung (abgesicherte Events)
-- ---------------------------------------------------------------------------

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2BANK' or '^1BANK', msg } })
end

Core:RegisterSecureEvent('hrp:banking:deposit', {
    rate = 1, burst = 3,
    schema = { { type = 'number', integer = true, min = 1, max = 1000000000 } },
}, function(src, amount)
    if not isAtBank(src) then return reply(src, false, 'Du bist nicht an einer Bank / einem ATM.') end
    local ident = Core:GetPlayerIdentity(src)
    getAccountNumber(ident.characterId)

    local correlationId = Logger:NewCorrelationId()
    local ok, err = Core:MoneyTransfer(ident.characterId, 'cash', ident.characterId, 'bank',
        amount, 'bank.deposit', { correlationId = correlationId })
    reply(src, ok, ok and ('%s $ eingezahlt.'):format(string.format('%.2f', amount / 100))
        or (err == 'insufficient_funds' and 'Nicht genug Bargeld.' or 'Einzahlung fehlgeschlagen.'))
end)

Core:RegisterSecureEvent('hrp:banking:withdraw', {
    rate = 1, burst = 3,
    schema = { { type = 'number', integer = true, min = 1, max = 1000000000 } },
}, function(src, amount)
    if not isAtBank(src) then return reply(src, false, 'Du bist nicht an einer Bank / einem ATM.') end
    local ident = Core:GetPlayerIdentity(src)

    -- Kontostand darf durch Abhebung nicht negativ werden
    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < amount then return reply(src, false, 'Kontostand zu niedrig.') end

    local ok = Core:MoneyTransfer(ident.characterId, 'bank', ident.characterId, 'cash',
        amount, 'bank.withdraw')
    reply(src, ok, ok and ('%s $ abgehoben.'):format(string.format('%.2f', amount / 100))
        or 'Abhebung fehlgeschlagen.')
end)

Core:RegisterSecureEvent('hrp:banking:transfer', {
    rate = 0.5, burst = 2,
    schema = {
        { type = 'string', maxLen = 10, pattern = '^LS%d%d%d%d%d%d%d%d$' },  -- Ziel-Kontonummer
        { type = 'number', integer = true, min = 1, max = 1000000000 },
        { type = 'string', maxLen = 128, optional = true },                   -- Verwendungszweck
    },
}, function(src, toNumber, amount, reference)
    if not isAtBank(src) then return reply(src, false, 'Überweisungen nur an einer Bank / einem ATM.') end
    local ident = Core:GetPlayerIdentity(src)

    local toCharacterId = Db.scalar('SELECT character_id FROM bank_details WHERE account_number = ?', { toNumber })
    if not toCharacterId then return reply(src, false, 'Unbekannte Kontonummer.') end
    if toCharacterId == ident.characterId then return reply(src, false, 'Überweisung an das eigene Konto.') end

    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < amount then return reply(src, false, 'Kontostand zu niedrig.') end

    local ok = Core:MoneyTransfer(ident.characterId, 'bank', toCharacterId, 'bank', amount, 'bank.transfer')
    if ok and reference and reference ~= '' then
        -- Verwendungszweck als eigenes Detail-Event am selben Vorgang wäre Phase-5-
        -- Feinschliff; bis dahin reicht der money.transfer-Eintrag.
    end
    reply(src, ok, ok and ('%s $ an %s überwiesen.'):format(string.format('%.2f', amount / 100), toNumber)
        or 'Überweisung fehlgeschlagen.')
end)

Core:RegisterSecureEvent('hrp:banking:balance', { rate = 1, burst = 3 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local number = getAccountNumber(ident.characterId) or '—'
    local bank = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    local cash = Core:MoneyGetBalance(ident.characterId, 'cash') or 0
    reply(src, true, ('Konto %s · Bank: %s $ · Bar: %s $')
        :format(number, string.format('%.2f', bank / 100), string.format('%.2f', cash / 100)))
end)

-- ---------------------------------------------------------------------------
-- Kredite: Bonität aus ECHTEN Verhaltensdaten (Spielzeit, offene Bußgelder,
-- Sanktionen). Auszahlung = money.create(loan.disbursement), Raten werden
-- stündlich automatisch abgebucht; 24 verpasste Raten = Kreditausfall.
-- ---------------------------------------------------------------------------

local function creditLimit(characterId, accountId)
    local playedMinutes = Db.scalar('SELECT played_minutes FROM characters WHERE id = ?', { characterId }) or 0
    local openFines = Db.scalar(
        "SELECT COUNT(*) FROM fines WHERE character_id = ? AND status = 'open'", { characterId }) or 0
    local sanctions = Db.scalar(
        'SELECT COUNT(*) FROM sanctions WHERE account_id = ?', { accountId }) or 0
    local defaults = Db.scalar(
        "SELECT COUNT(*) FROM loans WHERE character_id = ? AND status = 'defaulted'", { characterId }) or 0

    local perHour = Core:TuningGet('banking.loan_per_played_hour', 20000)  -- Cent
    local limit = math.floor(playedMinutes / 60) * perHour
        - openFines * 50000 - sanctions * 200000 - defaults * 1000000
    return math.max(0, limit), { playedMinutes = playedMinutes, openFines = openFines,
                                 sanctions = sanctions, defaults = defaults }
end

Core:RegisterSecureEvent('hrp:banking:loanInfo', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local active = Db.single(
        "SELECT id, remaining, missed FROM loans WHERE character_id = ? AND status = 'active'",
        { ident.characterId })
    if active then
        return reply(src, true, ('Kredit #%d: noch %s $ offen · %d verpasste Rate(n).')
            :format(active.id, string.format('%.2f', active.remaining / 100), active.missed))
    end
    local limit = creditLimit(ident.characterId, ident.accountId)
    reply(src, true, ('Dein Kreditrahmen: %s $ (Bonität aus Spielzeit, Bußgeldern, Sanktionen).')
        :format(string.format('%.2f', limit / 100)))
end)

Core:RegisterSecureEvent('hrp:banking:loan', {
    rate = 0.2, burst = 1,
    schema = { { type = 'number', integer = true, min = 10000, max = 10000000000 } },
}, function(src, amount)
    if not isAtBank(src) then return reply(src, false, 'Kredite gibt es nur in der Bank.') end
    local ident = Core:GetPlayerIdentity(src)

    if Db.scalar("SELECT 1 FROM loans WHERE character_id = ? AND status = 'active'", { ident.characterId }) then
        return reply(src, false, 'Du hast bereits einen laufenden Kredit.')
    end

    local limit, score = creditLimit(ident.characterId, ident.accountId)
    if amount > limit then
        return reply(src, false, ('Abgelehnt — dein Kreditrahmen liegt bei %s $.')
            :format(string.format('%.2f', limit / 100)))
    end

    local rate = Core:TuningGet('banking.loan_interest', 0.10)
    local owed = math.floor(amount * (1 + rate))
    local correlationId = Logger:NewCorrelationId()

    local loanId = Db.insert(
        'INSERT INTO loans (character_id, principal, remaining, interest_rate) VALUES (?, ?, ?, ?)',
        { ident.characterId, amount, owed, rate })
    Core:MoneyCreate(ident.characterId, 'bank', amount, 'loan.disbursement', { correlationId = correlationId })

    Core:Log(src, 'bank.loan_granted', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        correlationId = correlationId,
        payload = { loanId = loanId, principal = amount, owed = owed, rate = rate, creditScore = score },
    })
    reply(src, true, ('Kredit ausgezahlt: %s $ · Rückzahlung %s $ (%.0f %% Zins), Raten stündlich automatisch.')
        :format(string.format('%.2f', amount / 100), string.format('%.2f', owed / 100), rate * 100))
end)

-- Raten-Einzug (stündlich)
CreateThread(function()
    while true do
        Wait(3600000)
        local installmentRate = Core:TuningGet('banking.loan_installment_rate', 0.05)
        local minInstallment = Core:TuningGet('banking.loan_min_installment', 5000)

        local active = Db.query("SELECT * FROM loans WHERE status = 'active'") or {}
        for _, loan in ipairs(active) do
            local installment = math.min(loan.remaining,
                math.max(minInstallment, math.floor(loan.remaining * installmentRate)))
            local paid = Core:MoneyDestroy(loan.character_id, 'bank', installment, 'loan.repayment')

            if paid then
                local remaining = loan.remaining - installment
                Db.update('UPDATE loans SET remaining = ?, missed = 0 WHERE id = ?', { remaining, loan.id })
                if remaining <= 0 then
                    Db.update("UPDATE loans SET status = 'paid', closed_at = NOW(3) WHERE id = ?", { loan.id })
                    Logger:Log('bank.loan_paid', {
                        target = { kind = 'character', id = tostring(loan.character_id) },
                        payload = { loanId = loan.id },
                    })
                end
            else
                local missed = loan.missed + 1
                if missed >= Core:TuningGet('banking.loan_default_after_missed', 24) then
                    Db.update("UPDATE loans SET status = 'defaulted', missed = ?, closed_at = NOW(3) WHERE id = ?",
                        { missed, loan.id })
                    Logger:Log('bank.loan_defaulted', {
                        target = { kind = 'character', id = tostring(loan.character_id) },
                        payload = { loanId = loan.id, remaining = loan.remaining },
                    })
                else
                    Db.update('UPDATE loans SET missed = ? WHERE id = ?', { missed, loan.id })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Daueraufträge
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:banking:standingOrder', {
    rate = 0.5, burst = 2,
    schema = {
        { type = 'string', maxLen = 10, pattern = '^LS%d%d%d%d%d%d%d%d$' },
        { type = 'number', integer = true, min = 1, max = 1000000000 },
        { type = 'number', integer = true, min = 1, max = 720 },   -- Intervall Stunden
    },
}, function(src, toNumber, amount, intervalHours)
    if not isAtBank(src) then return reply(src, false, 'Daueraufträge nur an einer Bank.') end
    local ident = Core:GetPlayerIdentity(src)
    if not Db.scalar('SELECT 1 FROM bank_details WHERE account_number = ?', { toNumber }) then
        return reply(src, false, 'Unbekannte Kontonummer.')
    end

    local orderId = Db.insert([[
        INSERT INTO standing_orders (from_character_id, to_account_number, amount, interval_hours, next_run_at)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(3), INTERVAL ? HOUR))
    ]], { ident.characterId, toNumber, amount, intervalHours, intervalHours })

    Core:Log(src, 'bank.standing_order_create', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        payload = { orderId = orderId, toAccountNumber = toNumber, amount = amount, intervalHours = intervalHours },
    })
    reply(src, true, ('Dauerauftrag #%d angelegt: %s $ alle %d h an %s.')
        :format(orderId, string.format('%.2f', amount / 100), intervalHours, toNumber))
end)

-- Ausführung fälliger Daueraufträge (auch offline-Empfänger; Sender muss Deckung haben)
CreateThread(function()
    while true do
        Wait(60000)
        local due = Db.query([[
            SELECT so.id, so.from_character_id, so.to_account_number, so.amount, so.interval_hours,
                   bd.character_id AS to_character_id
            FROM standing_orders so
            JOIN bank_details bd ON bd.account_number = so.to_account_number
            WHERE so.active = 1 AND so.next_run_at <= NOW(3)
            LIMIT 50
        ]]) or {}

        for _, order in ipairs(due) do
            local ok, err = Core:MoneyTransfer(order.from_character_id, 'bank',
                order.to_character_id, 'bank', order.amount, 'bank.standing_order')
            if ok then
                Db.update('UPDATE standing_orders SET next_run_at = DATE_ADD(NOW(3), INTERVAL interval_hours HOUR) WHERE id = ?',
                    { order.id })
            else
                -- Keine Deckung: Auftrag pausieren statt Endlosversuche (geloggt)
                Db.update('UPDATE standing_orders SET active = 0 WHERE id = ?', { order.id })
                Logger:Log('bank.standing_order_failed', {
                    target = { kind = 'character', id = tostring(order.from_character_id) },
                    payload = { orderId = order.id, error = err },
                })
            end
        end
    end
end)
