--[[
    hrp_jobs – Grundgerüst: ein Job pro Charakter, Grades, Dienststatus,
    automatischer Lohnlauf für Beamte im Dienst.

    Phase 3 baut hierauf die Fraktionssysteme (MDT, Akten, Funk) auf;
    Phase 4 koppelt Löhne an die Staatskasse. Bis dahin: money.create
    mit reason 'state.salary' (Quelle Staat, vollständig geloggt).
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local function getJob(characterId)
    return Db.single([[
        SELECT cj.job_id, cj.grade, cj.on_duty, j.name, j.label, j.is_state, g.label AS grade_label, g.salary
        FROM character_jobs cj
        JOIN jobs j ON j.id = cj.job_id
        LEFT JOIN job_grades g ON g.job_id = cj.job_id AND g.grade = cj.grade
        WHERE cj.character_id = ?
    ]], { characterId })
end

exports('GetJob', getJob)

--- Job setzen (Server-API; in-game nur via Admin oder später Fraktionsleitung).
local function setJob(characterId, jobName, grade, byAccountId, srcForLog)
    local job = Db.single('SELECT id, name FROM jobs WHERE name = ?', { jobName })
    if not job then return false, 'unknown_job' end
    grade = tonumber(grade) or 0
    local gradeRow = Db.single('SELECT grade FROM job_grades WHERE job_id = ? AND grade = ?', { job.id, grade })
    if not gradeRow then return false, 'unknown_grade' end

    local before = getJob(characterId)
    Db.update([[
        INSERT INTO character_jobs (character_id, job_id, grade, on_duty)
        VALUES (?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE job_id = VALUES(job_id), grade = VALUES(grade), on_duty = 0, hired_at = NOW(3)
    ]], { characterId, job.id, grade })

    Core:Log(srcForLog, 'job.assign', {
        target = { kind = 'character', id = tostring(characterId) },
        payload = {
            characterId = characterId,
            before = before and { job = before.name, grade = before.grade } or nil,
            after = { job = jobName, grade = grade },
            byAccountId = byAccountId,
        },
    })
    return true
end

exports('SetJob', setJob)

-- /setjob <serverId> <job> <grade> — Admin (Fraktionsverwaltung folgt im ACP)
RegisterCommand('setjob', function(src, args)
    if src ~= 0 and not Core:HasPermission(src, 'game.admin.job_set') then return end
    local targetSrc, jobName, grade = tonumber(args[1]), args[2], tonumber(args[3]) or 0
    if not targetSrc or not jobName then print('Usage: setjob <serverId> <job> [grade]') return end
    local target = Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return end

    if src ~= 0 then
        local admin = Core:GetPlayerIdentity(src)
        Core:Log(src, 'admin.action', {
            target = { kind = 'account', id = tostring(target.accountId) },
            payload = { action = 'setjob', targetCharacterId = target.characterId,
                        args = { jobName, grade }, permission = 'game.admin.job_set' },
        })
    end

    local ok, err = setJob(target.characterId, jobName, grade,
        src ~= 0 and Core:GetPlayerIdentity(src).accountId or nil, src ~= 0 and src or nil)
    local msg = ok and 'Job gesetzt.' or ('Fehler: ' .. tostring(err))
    if src ~= 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2JOB' or '^1JOB', msg } })
    else
        print(msg)
    end
end, true)

-- Dienst an/aus
Core:RegisterSecureEvent('hrp:jobs:toggleDuty', { rate = 0.5, burst = 2 }, function(src)
    local ident = Core:GetPlayerIdentity(src)
    local job = getJob(ident.characterId)
    if not job then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1JOB', 'Du hast keinen Job.' } })
        return
    end
    local newDuty = job.on_duty == 1 and 0 or 1
    Db.update('UPDATE character_jobs SET on_duty = ? WHERE character_id = ?', { newDuty, ident.characterId })

    Core:Log(src, 'job.duty', {
        target = { kind = 'character', id = tostring(ident.characterId) },
        payload = { characterId = ident.characterId, job = job.name, onDuty = newDuty == 1 },
    })
    TriggerClientEvent('chat:addMessage', src, {
        args = { '^2JOB', newDuty == 1 and ('Dienst begonnen: ' .. job.label) or 'Dienst beendet.' },
    })
end)

-- ---------------------------------------------------------------------------
-- Lohnlauf: zahlt allen Charakteren IM DIENST ihr Grade-Gehalt.
-- Intervall + globaler Lohn-Multiplikator live über Tuning steuerbar.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local minutes = Core:TuningGet('jobs.salary_interval_minutes', 30)
        Wait(math.max(5, minutes) * 60000)

        local multiplier = Core:TuningGet('jobs.salary_multiplier', 1.0)
        local correlationId = Logger:NewCorrelationId()
        local paidCount = 0

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            if ident and ident.characterId then
                local job = getJob(ident.characterId)
                if job and job.on_duty == 1 and (job.salary or 0) > 0 then
                    local amount = math.floor(job.salary * multiplier)
                    if amount > 0 then
                        Core:MoneyCreate(ident.characterId, 'bank', amount, 'state.salary', { correlationId = correlationId })
                        paidCount = paidCount + 1
                        TriggerClientEvent('chat:addMessage', src, {
                            args = { '^2LOHN', ('Gehalt eingegangen: %s $'):format(string.format('%.2f', amount / 100)) },
                        })
                    end
                end
            end
        end

        if paidCount > 0 then
            Logger:Log('job.payroll', { payload = { paidCount = paidCount, multiplier = multiplier },
                                        correlationId = correlationId })
        end
    end
end)
