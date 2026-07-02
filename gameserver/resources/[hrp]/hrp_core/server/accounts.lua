--[[
    Connect-Flow (playerConnecting, mit Deferrals):
    1. license-Identifier ermitteln (Pflicht)
    2. Account laden oder anlegen
    3. Ban-Prüfung (aktive Bans blocken)
    4. Whitelist-Prüfung (Convar hrp_whitelist_enforce, Default an)
    5. Session anlegen, Identifier-Historie aktualisieren
    -> session.connect / session.drop Events
]]

local whitelistEnforce = GetConvarInt('hrp_whitelist_enforce', 1) == 1

local function getIdentifier(src, prefix)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #prefix) == prefix then
            return id
        end
    end
    return nil
end

local function collectIdentifiers(src)
    local out = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local kind, value = id:match('^([^:]+):(.+)$')
            if kind then out[kind] = value end
        end
    end
    return out
end

local function upsertIdentifier(accountId, idType, idValue)
    Db.update([[
        INSERT INTO account_identifiers (account_id, id_type, id_value)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE last_seen = CURRENT_TIMESTAMP(3)
    ]], { accountId, idType, idValue })
end

AddEventHandler('playerConnecting', function(playerName, _, deferrals)
    local src = source
    local connectStart = GetGameTimer()
    deferrals.defer()
    Wait(0)
    deferrals.update('Account wird geprüft ...')

    local license = getIdentifier(src, 'license:')
    if not license then
        deferrals.done('Verbindung abgelehnt: Keine gültige Cfx-Lizenz gefunden.')
        return
    end

    -- Account laden/anlegen
    local account = Db.single('SELECT id, whitelist_status FROM accounts WHERE license = ?', { license })
    if not account then
        local username = playerName:gsub('[^%w_%-%. ]', ''):sub(1, 32)
        -- Kollisionen auf username vermeiden: license-Suffix anhängen
        local suffix = license:sub(-6)
        local accountId = Db.insert(
            'INSERT INTO accounts (username, license) VALUES (?, ?)',
            { ('%s#%s'):format(username, suffix), license }
        )
        account = { id = accountId, whitelist_status = 'none' }
    end

    -- Ban-Prüfung
    local ban = Db.single([[
        SELECT id, reason, expires_at FROM account_bans
        WHERE account_id = ? AND revoked_at IS NULL
          AND (expires_at IS NULL OR expires_at > NOW(3))
        ORDER BY created_at DESC LIMIT 1
    ]], { account.id })
    if ban then
        local until_ = ban.expires_at and ('bis ' .. tostring(ban.expires_at)) or 'permanent'
        deferrals.done(('Du bist gebannt (%s). Grund: %s'):format(until_, ban.reason))
        return
    end

    -- Whitelist
    if whitelistEnforce and account.whitelist_status ~= 'approved' then
        deferrals.done('Du bist noch nicht freigeschaltet. Bewirb dich im UCP.')
        return
    end

    -- Session anlegen
    local ip = (GetPlayerEndpoint(src) or 'unknown'):gsub(':%d+$', '')
    local sessionId = exports.hrp_logger:NewCorrelationId()
    Db.insert('INSERT INTO sessions (id, account_id, ip) VALUES (?, ?, ?)', { sessionId, account.id, ip })
    Db.update('UPDATE accounts SET last_login_at = NOW(3) WHERE id = ?', { account.id })

    local identifiers = collectIdentifiers(src)
    for kind, value in pairs(identifiers) do
        if kind == 'ip' or kind == 'license' or kind == 'discord' or kind == 'steam' or kind == 'fivem' then
            upsertIdentifier(account.id, kind, value)
        end
    end

    -- Registry füllen — src ist während playerConnecting temporär; endgültige
    -- Übernahme in playerJoining (gleiche Quelle über state bag wäre Alternative)
    HRP.PendingSessions = HRP.PendingSessions or {}
    HRP.PendingSessions[license] = { accountId = account.id, sessionId = sessionId, ip = ip }

    exports.hrp_logger:Log('session.connect', {
        actor = { accountId = account.id, sessionId = sessionId },
        payload = {
            ip = ip,
            identifiers = { license = license, discord = identifiers.discord },
            queueTimeMs = GetGameTimer() - connectStart,
        },
    })

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    local license = getIdentifier(src, 'license:')
    local pending = license and HRP.PendingSessions and HRP.PendingSessions[license]
    if not pending then
        -- Kein abgeschlossener Connect-Flow -> kicken (Session-Bindung erzwingen)
        DropPlayer(src, 'Session-Fehler. Bitte neu verbinden.')
        return
    end
    HRP.PendingSessions[license] = nil
    HRP.Players[src] = {
        accountId = pending.accountId,
        sessionId = pending.sessionId,
        ip = pending.ip,
        characterId = nil,
        permissions = nil,   -- lazy durch rbac.lua geladen
        joinedAt = os.time(),
    }
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local p = HRP.Players[src]
    if not p then return end

    Db.update('UPDATE sessions SET ended_at = NOW(3), end_reason = ? WHERE id = ?', { reason or 'unknown', p.sessionId })

    HRP.Log(src, 'session.drop', {
        payload = { reason = reason or 'unknown', durationSec = os.time() - p.joinedAt },
    })

    -- Charakter-Save übernimmt hrp_characters über dieses Event, bevor die Registry geleert wird
    TriggerEvent('hrp:core:playerDropped', src, p)
    HRP.Players[src] = nil
end)
