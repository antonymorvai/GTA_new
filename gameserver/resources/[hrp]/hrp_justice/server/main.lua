--[[
    hrp_justice – Gesetzbuch (versioniert, in-RP änderbar), Bußgelder, Haft.

    - Gesetze sind Daten: Richter (justice, ab Grade 2) ändern Bußgeld/Haftzeit
      per /lawset — Versions-Bump, law_history-Snapshot, law.change-Event.
      Der volle Gesetzgebungs-Workflow (Entwurf -> Abstimmung -> Inkrafttreten)
      folgt mit dem Regierungs-Modul in Phase 4 auf dieser Datenbasis.
    - Bußgelder referenzieren Gesetzes-Codes; Zahlung = money.destroy(fine.payment).
    - Haft: server-seitiger Timer, Gefängnis-Spawn, Wiedereinsperren nach Reconnect.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs

local PRISON = vector4(1690.6, 2565.9, 45.6, 180.0)
local RELEASE = vector4(1848.2, 2585.9, 45.7, 90.0)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^3JUSTIZ' or '^1JUSTIZ', msg } })
end

local function jobIdent(src, jobName, minGrade)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return nil end
    local job = Jobs:GetJob(ident.characterId)
    if not job or job.name ~= jobName or job.on_duty ~= 1 then return nil end
    if minGrade and job.grade < minGrade then return nil end
    return ident, job
end

local function isJudge(src) return jobIdent(src, 'justice', 2) end
local function isOfficer(src, minGrade) return jobIdent(src, 'police', minGrade) end

-- ---------------------------------------------------------------------------
-- Gesetzbuch
-- ---------------------------------------------------------------------------

RegisterCommand('laws', function(src)
    if src == 0 then return end
    local rows = Db.query('SELECT code, title, fine, jail_minutes FROM laws WHERE active = 1 ORDER BY code') or {}
    for _, l in ipairs(rows) do
        reply(src, true, ('%s — %s · %s $ · %d min Haft'):format(
            l.code, l.title, string.format('%.2f', l.fine / 100), l.jail_minutes))
    end
end, false)

-- /lawset <code> <fineEuro> <jailMinutes>  (Richter)
RegisterCommand('lawset', function(src, args)
    if src == 0 then return end
    local ident = isJudge(src)
    if not ident then return reply(src, false, 'Nur Richter im Dienst.') end
    local code, fineEuro, jailMinutes = args[1], tonumber(args[2]), tonumber(args[3])
    if not code or not fineEuro or not jailMinutes or fineEuro < 0 or jailMinutes < 0 then
        return reply(src, false, 'Nutzung: /lawset <code> <bußgeldEuro> <haftMinuten>')
    end

    local law = Db.single('SELECT * FROM laws WHERE code = ?', { code })
    if not law then return reply(src, false, 'Unbekannter Gesetzes-Code.') end

    local newFine = math.floor(fineEuro * 100)
    local newVersion = law.version + 1
    Db.update('UPDATE laws SET fine = ?, jail_minutes = ?, version = ? WHERE code = ?',
        { newFine, math.floor(jailMinutes), newVersion, code })
    Db.insert('INSERT INTO law_history (law_code, version, snapshot, changed_by) VALUES (?, ?, ?, ?)', {
        code, newVersion,
        json.encode({ code = code, title = law.title, fine = newFine,
                      jailMinutes = math.floor(jailMinutes), version = newVersion }),
        ident.characterId,
    })

    Core:Log(src, 'law.change', {
        target = { kind = 'law', id = code },
        payload = {
            code = code, version = newVersion,
            before = { fine = law.fine, jailMinutes = law.jail_minutes },
            after = { fine = newFine, jailMinutes = math.floor(jailMinutes) },
            changedByCharacterId = ident.characterId,
        },
    })
    reply(src, true, ('%s geändert (v%d): %s $ · %d min.'):format(code, newVersion, args[2], jailMinutes))
end, false)

-- ---------------------------------------------------------------------------
-- Bußgelder
-- ---------------------------------------------------------------------------

-- /fine <serverId> <lawCode> [notiz...]  (Polizei)
RegisterCommand('fine', function(src, args)
    if src == 0 then return end
    local ident = isOfficer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local targetSrc, lawCode = tonumber(args[1]), args[2]
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end

    local law = Db.single('SELECT code, title, fine FROM laws WHERE code = ? AND active = 1', { lawCode })
    if not law then return reply(src, false, 'Unbekannter Gesetzes-Code. Siehe /laws') end
    if law.fine <= 0 then return reply(src, false, 'Für dieses Gesetz ist kein Bußgeld vorgesehen.') end

    local note = table.concat(args, ' ', 3)
    local fineId = Db.insert(
        'INSERT INTO fines (character_id, law_code, amount, issued_by, note) VALUES (?, ?, ?, ?, ?)',
        { target.characterId, law.code, law.fine, ident.characterId, note })

    Core:Log(src, 'justice.fine', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { fineId = fineId, targetCharacterId = target.characterId, lawCode = law.code,
                    amount = law.fine, issuedByCharacterId = ident.characterId, note = note },
    })
    reply(src, true, ('Bußgeld #%d ausgestellt: %s (%s $).'):format(fineId, law.code, string.format('%.2f', law.fine / 100)))
    reply(targetSrc, false, ('Bußgeld #%d: %s — %s (%s $). Zahlen mit /payfine %d')
        :format(fineId, law.code, law.title, string.format('%.2f', law.fine / 100), fineId))
end, false)

-- /myfines
RegisterCommand('myfines', function(src)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local rows = Db.query(
        "SELECT id, law_code, amount FROM fines WHERE character_id = ? AND status = 'open'",
        { ident.characterId }) or {}
    if #rows == 0 then return reply(src, true, 'Keine offenen Bußgelder.') end
    for _, f in ipairs(rows) do
        reply(src, true, ('#%d · %s · %s $'):format(f.id, f.law_code, string.format('%.2f', f.amount / 100)))
    end
end, false)

-- /payfine <fineId> — Zahlung vom Bankkonto (Senke: Staat)
RegisterCommand('payfine', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local fineId = tonumber(args[1])
    if not fineId then return reply(src, false, 'Nutzung: /payfine <bußgeldId>') end

    local fine = Db.single(
        "SELECT id, amount, law_code FROM fines WHERE id = ? AND character_id = ? AND status = 'open'",
        { fineId, ident.characterId })
    if not fine then return reply(src, false, 'Kein offenes Bußgeld mit dieser Nummer.') end

    local balance = Core:MoneyGetBalance(ident.characterId, 'bank') or 0
    if balance < fine.amount then return reply(src, false, 'Kontostand zu niedrig.') end

    local correlationId = exports.hrp_logger:NewCorrelationId()
    local paid = Core:MoneyDestroy(ident.characterId, 'bank', fine.amount, 'fine.payment',
        { correlationId = correlationId })
    if not paid then return reply(src, false, 'Zahlung fehlgeschlagen.') end

    Db.update("UPDATE fines SET status = 'paid', paid_at = NOW(3) WHERE id = ?", { fine.id })
    Core:TreasuryCredit(fine.amount, 'fine.payment', { correlationId = correlationId })
    Core:Log(src, 'justice.fine_paid', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        correlationId = correlationId,
        payload = { fineId = fine.id, lawCode = fine.law_code, amount = fine.amount },
    })
    reply(src, true, ('Bußgeld #%d bezahlt (%s $).'):format(fine.id, string.format('%.2f', fine.amount / 100)))
end, false)

--- System-Bußgeld (z. B. Blitzer): kein ausstellender Beamter, automatisiert.
local function issueSystemFine(characterId, lawCode, note)
    local law = Db.single('SELECT code, title, fine FROM laws WHERE code = ? AND active = 1', { lawCode })
    if not law or law.fine <= 0 then return nil end

    local fineId = Db.insert(
        'INSERT INTO fines (character_id, law_code, amount, issued_by, note) VALUES (?, ?, ?, NULL, ?)',
        { characterId, law.code, law.fine, note or 'automatisiert' })

    exports.hrp_logger:Log('justice.fine', {
        target = { kind = 'character', id = tostring(characterId) },
        payload = { fineId = fineId, targetCharacterId = characterId, lawCode = law.code,
                    amount = law.fine, automated = true, note = note },
    })
    return fineId, law.fine
end

exports('IssueSystemFine', issueSystemFine)

-- ---------------------------------------------------------------------------
-- Haft
-- ---------------------------------------------------------------------------

local jailed = {}   -- jailed[src] = sentenceId

local function jailPlayer(src, sentence)
    jailed[src] = sentence.id
    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 10000) end)
    TriggerClientEvent('hrp:justice:jail', src, { x = PRISON.x, y = PRISON.y, z = PRISON.z, h = PRISON.w })
end

local function releasePlayer(src, sentenceId, releasedByCharacter, reason)
    Db.update('UPDATE jail_sentences SET released_at = NOW(3), released_by = ? WHERE id = ? AND released_at IS NULL',
        { releasedByCharacter, sentenceId })
    jailed[src] = nil
    pcall(function() exports.hrp_anticheat:AllowTeleport(src, 10000) end)
    local ident = Core:GetPlayerIdentity(src)
    Core:Log(src, 'justice.release', {
        target = ident and { kind = 'character', id = tostring(ident.characterId) } or nil,
        payload = { sentenceId = sentenceId, reason = reason,
                    releasedByCharacterId = releasedByCharacter },
    })
    TriggerClientEvent('hrp:justice:release', src, { x = RELEASE.x, y = RELEASE.y, z = RELEASE.z, h = RELEASE.w })
    reply(src, true, 'Du wurdest aus der Haft entlassen.')
end

-- /jail <serverId> <minuten> <grund...>  (Richter oder Polizei ab Lieutenant)
RegisterCommand('jail', function(src, args)
    if src == 0 then return end
    local ident = isJudge(src) or isOfficer(src, 3)
    if not ident then return reply(src, false, 'Nur Richter oder Polizei ab Lieutenant.') end
    local targetSrc, minutes = tonumber(args[1]), tonumber(args[2])
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    local maxMinutes = Core:TuningGet('justice.max_jail_minutes', 120)
    if not minutes or minutes < 1 or minutes > maxMinutes then
        return reply(src, false, ('Haftzeit 1-%d Minuten.'):format(maxMinutes))
    end
    local reason = table.concat(args, ' ', 3)
    if reason == '' then return reply(src, false, 'Ein Haftgrund ist Pflicht.') end

    local sentenceId = Db.insert([[
        INSERT INTO jail_sentences (character_id, minutes, reason, issued_by, ends_at)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(3), INTERVAL ? MINUTE))
    ]], { target.characterId, minutes, reason, ident.characterId, minutes })

    Core:Log(src, 'justice.jail', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { sentenceId = sentenceId, targetCharacterId = target.characterId,
                    minutes = minutes, reason = reason, issuedByCharacterId = ident.characterId },
    })
    jailPlayer(targetSrc, { id = sentenceId })
    reply(src, true, ('Haftstrafe #%d: %d Minuten.'):format(sentenceId, minutes))
    reply(targetSrc, false, ('Du wurdest inhaftiert: %d Minuten — %s'):format(minutes, reason))
end, false)

-- /release <serverId>  (Richter)
RegisterCommand('release', function(src, args)
    if src == 0 then return end
    local ident = isJudge(src)
    if not ident then return reply(src, false, 'Nur Richter im Dienst.') end
    local targetSrc = tonumber(args[1])
    if not targetSrc or not jailed[targetSrc] then return reply(src, false, 'Dieser Spieler ist nicht inhaftiert.') end
    releasePlayer(targetSrc, jailed[targetSrc], ident.characterId, 'early_release')
end, false)

-- Haft-Timer + Wiedereinsperren nach Reconnect/Charakterwahl
CreateThread(function()
    while true do
        Wait(15000)
        -- Abgelaufene Strafen entlassen
        for src, sentenceId in pairs(jailed) do
            local stillActive = Db.scalar(
                'SELECT 1 FROM jail_sentences WHERE id = ? AND released_at IS NULL AND ends_at > NOW(3)',
                { sentenceId })
            if not stillActive then
                Db.update('UPDATE jail_sentences SET released_at = NOW(3) WHERE id = ? AND released_at IS NULL', { sentenceId })
                releasePlayer(src, sentenceId, nil, 'served')
            end
        end
        -- Online-Spieler mit aktiver Strafe, die nicht markiert sind (Reconnect)
        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            if not jailed[src] then
                local ident = Core:GetPlayerIdentity(src)
                if ident and ident.characterId then
                    local sentence = Db.single([[
                        SELECT id FROM jail_sentences
                        WHERE character_id = ? AND released_at IS NULL AND ends_at > NOW(3)
                    ]], { ident.characterId })
                    if sentence then jailPlayer(src, sentence) end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    jailed[source] = nil
end)
