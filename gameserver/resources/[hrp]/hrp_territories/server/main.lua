--[[
    hrp_territories – Gang-Einfluss pro Stadtteil als KONTINUIERLICHER Wert
    (0..100), kein Capture-Timer:
    - Aktivitäten (Drogen-Deals, Präsenz) erhöhen Einfluss (AddInfluence-Export)
    - Verfall pro Tick ohne Pflege (territory.tick)
    - Auswirkung: Preis-Multiplikator für Illegales im Gebiet (GetSaleModifier)
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local territories = {}

local function loadTerritories()
    territories = {}
    for _, row in ipairs(Db.query('SELECT * FROM territories') or {}) do
        territories[row.id] = row
    end
end
MySQL.ready(loadTerritories)

--- Territorium an einer Position (oder nil).
local function territoryAt(x, y)
    for id, t in pairs(territories) do
        local dx, dy = x - t.center_x, y - t.center_y
        if (dx * dx + dy * dy) <= (t.radius * t.radius) then return t end
    end
    return nil
end

local function gangOf(characterId)
    return Db.single([[
        SELECT g.id, g.name, g.label, gm.rank FROM gang_members gm
        JOIN gangs g ON g.id = gm.gang_id WHERE gm.character_id = ?
    ]], { characterId })
end

--- Einfluss erhöhen (von Aktivitäts-Modulen gerufen, z. B. hrp_drugs).
local function addInfluence(territoryId, gangId, amount, activity, srcForLog)
    if not territories[territoryId] then return false end
    local cap = Core:TuningGet('territories.influence_cap', 100)

    Db.update([[
        INSERT INTO territory_influence (territory_id, gang_id, influence)
        VALUES (?, ?, LEAST(?, ?))
        ON DUPLICATE KEY UPDATE influence = LEAST(?, influence + ?)
    ]], { territoryId, gangId, amount, cap, cap, amount })

    local after = Db.scalar(
        'SELECT influence FROM territory_influence WHERE territory_id = ? AND gang_id = ?',
        { territoryId, gangId })

    Core:Log(srcForLog, 'territory.influence_change', {
        target = { kind = 'territory', id = tostring(territoryId) },
        payload = { territoryId = territoryId, gangId = gangId, activity = activity,
                    delta = amount, influenceAfter = tonumber(after) },
    })
    return true
end

--- Verkaufs-Modifikator für Illegales: dominante eigene Gang = besserer Preis,
--- fremdes dominiertes Gebiet = Abschlag (Risiko/Konkurrenz).
local function getSaleModifier(x, y, characterId)
    local territory = territoryAt(x, y)
    if not territory then return 1.0, nil end

    local top = Db.single([[
        SELECT gang_id, influence FROM territory_influence
        WHERE territory_id = ? ORDER BY influence DESC LIMIT 1
    ]], { territory.id })
    if not top or tonumber(top.influence) < 10 then return 1.0, territory end

    local gang = gangOf(characterId)
    local strength = math.min(tonumber(top.influence), 100) / 100
    local bonus = Core:TuningGet('territories.sale_bonus_max', 0.25)
    local malus = Core:TuningGet('territories.sale_malus_max', 0.30)

    if gang and gang.id == top.gang_id then
        return 1.0 + bonus * strength, territory
    end
    return 1.0 - malus * strength, territory
end

exports('TerritoryAt', function(x, y) return territoryAt(x, y) end)
exports('GangOf', function(characterId) return gangOf(characterId) end)
exports('AddInfluence', addInfluence)
exports('GetSaleModifier', getSaleModifier)

-- Verfall ohne Pflege (territory.tick fasst alle Änderungen zusammen)
CreateThread(function()
    while true do
        local minutes = Core:TuningGet('territories.decay_tick_minutes', 60)
        Wait(math.max(5, minutes) * 60000)
        local decay = Core:TuningGet('territories.decay_per_tick', 2.0)

        Db.update('UPDATE territory_influence SET influence = GREATEST(0, influence - ?)', { decay })

        local snapshot = Db.query([[
            SELECT ti.territory_id, ti.gang_id, ti.influence, t.name
            FROM territory_influence ti JOIN territories t ON t.id = ti.territory_id
            WHERE ti.influence > 0
        ]]) or {}
        Logger:Log('territory.tick', { payload = { decay = decay, influence = snapshot } })
    end
end)

-- Gang-Verwaltung (Bootstrap über Admin; Fraktionsverwaltung folgt im UCP)
RegisterCommand('setgang', function(src, args)
    if src ~= 0 and not Core:HasPermission(src, 'game.admin.job_set') then return end
    local targetSrc, gangName, rank = tonumber(args[1]), args[2], tonumber(args[3]) or 0
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId or not gangName then
        if src == 0 then print('Usage: setgang <serverId> <gang|none> [rank]') end
        return
    end

    if gangName == 'none' then
        Db.update('DELETE FROM gang_members WHERE character_id = ?', { target.characterId })
    else
        local gangId = Db.scalar('SELECT id FROM gangs WHERE name = ?', { gangName })
        if not gangId then return end
        Db.update([[
            INSERT INTO gang_members (character_id, gang_id, rank) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE gang_id = VALUES(gang_id), rank = VALUES(rank)
        ]], { target.characterId, gangId, rank })
    end

    Core:Log(src ~= 0 and src or nil, 'admin.action', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { action = 'setgang', targetCharacterId = target.characterId,
                    args = { gangName, rank }, permission = 'game.admin.job_set' },
    })
end, true)
