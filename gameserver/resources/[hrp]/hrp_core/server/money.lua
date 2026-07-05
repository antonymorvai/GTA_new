--[[
    Geld-Basis-API (Kernprinzip A, money.*-Invariante):
    Salden liegen in character_money (Cent-genau, Integer). JEDE Mutation läuft
    über diese API, die Saldo-Update und Log-Event atomar koppelt. Direkte
    UPDATEs auf character_money sind verboten (Review-Regel).

    Die volle Wirtschafts-Engine (dynamische Preise, Banken) folgt in Phase 2
    und baut ausschließlich auf dieser API auf.
]]

HRP.Money = {}

local VALID_ACCOUNTS = { cash = true, bank = true }

local function getBalance(characterId, account)
    return Db.scalar(
        ('SELECT %s FROM character_money WHERE character_id = ?'):format(account),
        { characterId }
    )
end

local function applyDelta(characterId, account, delta)
    -- WHERE-Klausel verhindert negatives Bargeld race-frei
    local guard = (account == 'cash' and delta < 0) and (' AND cash + %d >= 0'):format(delta) or ''
    local affected = Db.update(
        ('UPDATE character_money SET %s = %s + ? WHERE character_id = ?%s'):format(account, account, guard),
        { delta, characterId }
    )
    return affected == 1
end

local function findSrcByCharacter(characterId)
    for src, p in pairs(HRP.Players) do
        if p.characterId == characterId then return src end
    end
    return nil
end

--- Geld erzeugen (Quelle). Gibt (ok, err) zurück.
--- opts = {correlationId?, adminAccountId?}
function HRP.Money.Create(characterId, account, amount, reason, opts)
    opts = opts or {}
    if not VALID_ACCOUNTS[account] then return false, 'invalid_account' end
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end

    if not applyDelta(characterId, account, amount) then return false, 'no_account' end
    local after = getBalance(characterId, account)

    HRP.Log(findSrcByCharacter(characterId), 'money.create', {
        target = { kind = 'character', id = tostring(characterId) },
        correlationId = opts.correlationId,
        payload = { account = account, amount = amount, reason = reason, balanceAfter = after,
                    adminAccountId = opts.adminAccountId },
    })
    return true
end

--- Geld vernichten (Senke).
function HRP.Money.Destroy(characterId, account, amount, reason, opts)
    opts = opts or {}
    if not VALID_ACCOUNTS[account] then return false, 'invalid_account' end
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end

    if not applyDelta(characterId, account, -amount) then return false, 'insufficient_funds' end
    local after = getBalance(characterId, account)

    HRP.Log(findSrcByCharacter(characterId), 'money.destroy', {
        target = { kind = 'character', id = tostring(characterId) },
        correlationId = opts.correlationId,
        payload = { account = account, amount = amount, reason = reason, balanceAfter = after,
                    adminAccountId = opts.adminAccountId },
    })
    return true
end

--- Transfer zwischen Charakteren/Konten.
function HRP.Money.Transfer(fromCharacterId, fromAccount, toCharacterId, toAccount, amount, reason, opts)
    opts = opts or {}
    if not VALID_ACCOUNTS[fromAccount] or not VALID_ACCOUNTS[toAccount] then return false, 'invalid_account' end
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end

    if not applyDelta(fromCharacterId, fromAccount, -amount) then return false, 'insufficient_funds' end
    if not applyDelta(toCharacterId, toAccount, amount) then
        -- Rollback der Abbuchung
        applyDelta(fromCharacterId, fromAccount, amount)
        return false, 'no_target_account'
    end

    local fromAfter = getBalance(fromCharacterId, fromAccount)
    local toAfter = getBalance(toCharacterId, toAccount)
    local correlationId = opts.correlationId or exports.hrp_logger:NewCorrelationId()

    HRP.Log(findSrcByCharacter(fromCharacterId), 'money.transfer', {
        target = { kind = 'character', id = tostring(toCharacterId) },
        correlationId = correlationId,
        payload = {
            from = { characterId = fromCharacterId, account = fromAccount },
            to = { characterId = toCharacterId, account = toAccount },
            amount = amount, reason = reason,
            fromBalanceAfter = fromAfter, toBalanceAfter = toAfter,
        },
    })
    return true
end

function HRP.Money.GetBalance(characterId, account)
    if not VALID_ACCOUNTS[account] then return nil end
    return getBalance(characterId, account)
end

-- ---------------------------------------------------------------------------
-- Staatskasse (state_treasury): Einnahmen aus Bußgeldern/Staatsverkäufen/
-- Steuern, Ausgaben für Staatslöhne. Leere Kasse = Debit schlägt fehl.
-- ---------------------------------------------------------------------------

HRP.Treasury = {}

local function treasuryDelta(delta)
    local guard = delta < 0 and (' AND balance + %d >= 0'):format(delta) or ''
    return Db.update(
        ('UPDATE state_treasury SET balance = balance + ? WHERE id = 1%s'):format(guard),
        { delta }) == 1
end

local function treasuryLog(direction, amount, reason, opts)
    exports.hrp_logger:Log('state.treasury', {
        target = { kind = 'state', id = 'treasury' },
        correlationId = opts and opts.correlationId,
        payload = {
            direction = direction, amount = amount, reason = reason,
            balanceAfter = Db.scalar('SELECT balance FROM state_treasury WHERE id = 1'),
        },
    })
end

--- Einnahme (Bußgeld, Staatsverkauf, Steuer).
function HRP.Treasury.Credit(amount, reason, opts)
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end
    treasuryDelta(amount)
    treasuryLog('credit', amount, reason, opts)
    return true
end

--- Ausgabe (Staatslöhne). Schlägt bei leerer Kasse fehl.
function HRP.Treasury.Debit(amount, reason, opts)
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end
    if not treasuryDelta(-amount) then return false, 'treasury_empty' end
    treasuryLog('debit', amount, reason, opts)
    return true
end

function HRP.Treasury.GetBalance()
    return Db.scalar('SELECT balance FROM state_treasury WHERE id = 1')
end

exports('TreasuryCredit', function(...) return HRP.Treasury.Credit(...) end)
exports('TreasuryDebit', function(...) return HRP.Treasury.Debit(...) end)
exports('TreasuryGetBalance', function() return HRP.Treasury.GetBalance() end)

-- ---------------------------------------------------------------------------
-- Firmenkonten (company_funds): gleiche Invariante, target kind 'company'.
-- ---------------------------------------------------------------------------

local function companyDelta(companyId, delta)
    local guard = delta < 0 and (' AND balance + %d >= 0'):format(delta) or ''
    return Db.update(
        ('UPDATE company_funds SET balance = balance + ? WHERE company_id = ?%s'):format(guard),
        { delta, companyId }) == 1
end

local function companyBalance(companyId)
    return Db.scalar('SELECT balance FROM company_funds WHERE company_id = ?', { companyId })
end

--- Charakter -> Firmenkonto (reason: company.deposit) bzw. zurück (company.withdraw / company.salary).
--- direction = 'to_company' | 'to_character'; account = 'cash'|'bank' auf Charakter-Seite.
function HRP.Money.CompanyTransfer(characterId, companyId, account, amount, direction, reason, opts)
    opts = opts or {}
    if not VALID_ACCOUNTS[account] then return false, 'invalid_account' end
    if type(amount) ~= 'number' or amount % 1 ~= 0 or amount <= 0 then return false, 'invalid_amount' end
    if not HRPReasons.IsValid('money', reason) then return false, 'unknown_reason' end

    if direction == 'to_company' then
        if not applyDelta(characterId, account, -amount) then return false, 'insufficient_funds' end
        if not companyDelta(companyId, amount) then
            applyDelta(characterId, account, amount)
            return false, 'no_company_account'
        end
    elseif direction == 'to_character' then
        if not companyDelta(companyId, -amount) then return false, 'insufficient_company_funds' end
        if not applyDelta(characterId, account, amount) then
            companyDelta(companyId, amount)
            return false, 'no_account'
        end
    else
        return false, 'invalid_direction'
    end

    HRP.Log(findSrcByCharacter(characterId), 'money.transfer', {
        target = { kind = 'company', id = tostring(companyId) },
        correlationId = opts.correlationId,
        payload = {
            from = direction == 'to_company' and { characterId = characterId, account = account }
                or { companyId = companyId },
            to = direction == 'to_company' and { companyId = companyId }
                or { characterId = characterId, account = account },
            amount = amount, reason = reason,
            companyBalanceAfter = companyBalance(companyId),
        },
    })
    return true
end

function HRP.Money.CompanyGetBalance(companyId)
    return companyBalance(companyId)
end

exports('MoneyCompanyTransfer', function(...) return HRP.Money.CompanyTransfer(...) end)
exports('MoneyCompanyGetBalance', function(...) return HRP.Money.CompanyGetBalance(...) end)

exports('MoneyCreate',   function(...) return HRP.Money.Create(...) end)
exports('MoneyDestroy',  function(...) return HRP.Money.Destroy(...) end)
exports('MoneyTransfer', function(...) return HRP.Money.Transfer(...) end)
exports('MoneyGetBalance', function(...) return HRP.Money.GetBalance(...) end)

-- ---------------------------------------------------------------------------
-- VERMÖGENSSTEUER: täglich, nur oberhalb des Freibetrags, auch offline —
-- wirkt der Vermögenskonzentration entgegen und speist die Staatskasse.
-- ---------------------------------------------------------------------------

CreateThread(function()
    local lastRunDay = nil
    while true do
        Wait(600000)  -- alle 10 min prüfen, ausführen 1x täglich zur Stunde X
        local hour = tonumber(os.date('%H'))
        local today = os.date('%Y-%m-%d')
        if hour == HRP.Tuning.Get('tax.wealth_hour', 4) and lastRunDay ~= today then
            lastRunDay = today
            local threshold = HRP.Tuning.Get('tax.wealth_threshold', 100000000)  -- 1 Mio $
            local rate = HRP.Tuning.Get('tax.wealth_rate', 0.005)                -- 0,5 %/Tag

            local rich = Db.query([[
                SELECT character_id, cash + bank AS total, bank FROM character_money
                WHERE cash + bank > ?
            ]], { threshold }) or {}

            for _, row in ipairs(rich) do
                local tax = math.floor((row.total - threshold) * rate)
                tax = math.min(tax, row.bank)   -- nur vom Konto, Bargeld bleibt (Anreiz: Bank meiden = Risiko)
                if tax > 0 then
                    local correlationId = exports.hrp_logger:NewCorrelationId()
                    local ok = HRP.Money.Destroy(row.character_id, 'bank', tax, 'tax.wealth',
                        { correlationId = correlationId })
                    if ok then
                        HRP.Treasury.Credit(tax, 'tax.wealth', { correlationId = correlationId })
                    end
                end
            end
            if #rich > 0 then
                print(('[hrp_core] Vermögenssteuer: %d Charaktere veranlagt.'):format(#rich))
            end
        end
    end
end)

-- Spieler-zu-Spieler-Bargeldübergabe (Beispiel eines abgesicherten Client-Events)
HRP.RegisterSecureEvent('hrp:money:giveCash', {
    rate = 1, burst = 3,
    schema = {
        { type = 'number', integer = true, min = 1 },       -- targetServerId
        { type = 'number', integer = true, min = 1, max = 100000000 }, -- Betrag in Cent
    },
}, function(src, targetSrc, amount)
    local giver = HRP.Players[src]
    local receiver = HRP.Players[targetSrc]
    if not receiver or not receiver.characterId then return end

    -- Distanz-Check: Übergabe nur in unmittelbarer Nähe (server-autoritativ)
    local p1, p2 = GetEntityCoords(GetPlayerPed(src)), GetEntityCoords(GetPlayerPed(targetSrc))
    if #(p1 - p2) > 3.0 then
        HRP.Log(src, 'security.invalid_event', {
            payload = { eventName = 'hrp:money:giveCash', violation = 'distance' },
        })
        return
    end

    local ok, err = HRP.Money.Transfer(giver.characterId, 'cash', receiver.characterId, 'cash', amount, 'trade.direct')
    TriggerClientEvent('hrp:money:giveCashResult', src, ok, err)
end)
