--[[
    hrp_skills – Fähigkeiten verbessern sich AUSSCHLIESSLICH durch Nutzung
    (Module rufen AddXp), mit täglichem Decay bei Nichtnutzung. Kein XP-Kauf.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core

local VALID_SKILLS = {
    driving = true, shooting = true, stamina = true, crafting = true,
    fishing = true, mining = true, logging = true, farming = true,
    hunting = true, hacking = true,
}

--- XP hinzufügen; loggt skill.level_up bei Level-Aufstieg.
local function addXp(characterId, skill, amount, srcForLog)
    if not VALID_SKILLS[skill] or amount <= 0 then return false end

    local row = Db.single('SELECT xp FROM character_skills WHERE character_id = ? AND skill = ?',
        { characterId, skill })
    local oldXp = row and row.xp or 0
    local newXp = oldXp + math.floor(amount)

    Db.update([[
        INSERT INTO character_skills (character_id, skill, xp, last_used_at)
        VALUES (?, ?, ?, NOW(3))
        ON DUPLICATE KEY UPDATE xp = VALUES(xp), last_used_at = NOW(3)
    ]], { characterId, skill, newXp })

    local oldLevel = HRPLeveling.XpToLevel(oldXp)
    local newLevel = HRPLeveling.XpToLevel(newXp)
    if newLevel > oldLevel then
        Core:Log(srcForLog, 'skill.level_up', {
            target = { kind = 'character', id = tostring(characterId) },
            payload = { characterId = characterId, skill = skill,
                        levelBefore = oldLevel, levelAfter = newLevel, xp = newXp },
        })
        if srcForLog then
            TriggerClientEvent('chat:addMessage', srcForLog, {
                args = { '^2SKILL', ('%s ist jetzt Level %d!'):format(skill, newLevel) },
            })
        end
    end
    return true
end

local function getLevel(characterId, skill)
    local xp = Db.single('SELECT xp FROM character_skills WHERE character_id = ? AND skill = ?',
        { characterId, skill })
    return HRPLeveling.XpToLevel(xp and xp.xp or 0)
end

exports('AddXp', addXp)
exports('GetLevel', getLevel)

RegisterCommand('skills', function(src)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local rows = Db.query('SELECT skill, xp FROM character_skills WHERE character_id = ? ORDER BY xp DESC',
        { ident.characterId }) or {}
    if #rows == 0 then
        TriggerClientEvent('chat:addMessage', src, { args = { '^3SKILL', 'Noch keine Fähigkeiten entwickelt.' } })
        return
    end
    for _, s in ipairs(rows) do
        TriggerClientEvent('chat:addMessage', src, {
            args = { '^3SKILL', ('%s: Level %d (%d XP)'):format(s.skill, HRPLeveling.XpToLevel(s.xp), s.xp) },
        })
    end
end, false)

-- Täglicher Decay-Lauf (Rate via Tuning; last_used_at schützt aktive Skills)
CreateThread(function()
    while true do
        Wait(3600000)  -- stündlich prüfen, wirkt pro Tag Nichtnutzung
        local ratePerDay = Core:TuningGet('skills.decay_rate_per_day', 0.02)
        local graceDays = Core:TuningGet('skills.decay_grace_days', 3)

        local rows = Db.query([[
            SELECT character_id, skill, xp, GREATEST(0, DATEDIFF(NOW(3), last_used_at) - ?) AS days_over
            FROM character_skills
            WHERE xp > 0 AND last_used_at < DATE_SUB(NOW(3), INTERVAL ? DAY)
        ]], { graceDays, graceDays }) or {}

        for _, row in ipairs(rows) do
            -- Decay einen Tages-Schritt anwenden (Lauf ist stündlich, aber
            -- days_over wächst nur täglich -> effektiv 1x pro Tag wirksam)
            local newXp = HRPLeveling.Decay(row.xp, 1, ratePerDay)
            if newXp < row.xp then
                Db.update('UPDATE character_skills SET xp = ? WHERE character_id = ? AND skill = ?',
                    { newXp, row.character_id, row.skill })
            end
        end
    end
end)
