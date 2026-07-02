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

exports('MoneyCreate',   function(...) return HRP.Money.Create(...) end)
exports('MoneyDestroy',  function(...) return HRP.Money.Destroy(...) end)
exports('MoneyTransfer', function(...) return HRP.Money.Transfer(...) end)
exports('MoneyGetBalance', function(...) return HRP.Money.GetBalance(...) end)

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
