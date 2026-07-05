--[[
    hrp_resources – dynamische Ressourcen-Pools (Kernprinzip B):
    Jeder Abbau senkt den Pool-Bestand; leere Pools werfen nichts mehr ab und
    regenerieren langsam -> Overfarming zwingt zum Gebietswechsel.
    Skill-Level erhöht den Ertrag; jede Ernte gibt Nutzungs-XP.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Inv = exports.hrp_inventory
local Skills = exports.hrp_skills
local Logger = exports.hrp_logger

-- pools[id] = row (in-memory Zustand, periodisch persistiert)
local pools = {}

local function loadPools()
    pools = {}
    for _, row in ipairs(Db.query('SELECT * FROM resource_pools WHERE active = 1') or {}) do
        pools[row.id] = row
    end
    print(('[hrp_resources] %d Pools geladen.'):format((function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end)(pools)))
end

MySQL.ready(loadPools)
RegisterCommand('hrp_resources_reload', function(src) if src == 0 then loadPools() end end, true)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2ERNTE' or '^1ERNTE', msg } })
end

local function findPoolNear(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for id, pool in pairs(pools) do
        if #(pos - vector3(pool.pos_x, pool.pos_y, pool.pos_z)) <= pool.radius then
            return pool
        end
    end
    return nil
end

--- Director-Hook: Ressourcen-Boom (Kapazität + Sofort-Regeneration).
local function boom(poolId, bonus)
    local pool = poolId and pools[poolId]
    if not pool then
        -- zufälligen Pool wählen
        local ids = {}
        for id in pairs(pools) do ids[#ids + 1] = id end
        if #ids == 0 then return nil end
        pool = pools[ids[math.random(#ids)]]
    end
    pool.current = math.min(pool.capacity, pool.current + (bonus or math.floor(pool.capacity / 2)))
    Db.update('UPDATE resource_pools SET current = ? WHERE id = ?', { pool.current, pool.id })
    return pool.label
end

exports('Boom', boom)

Core:RegisterSecureEvent('hrp:resources:harvest', { rate = 0.3, burst = 2 }, function(src)
    local pool = findPoolNear(src)
    if not pool then return reply(src, false, 'Hier gibt es nichts zu ernten/abzubauen.') end

    local ident = Core:GetPlayerIdentity(src)

    if pool.current < 1 then
        Core:Log(src, 'resource.depleted', {
            target = { kind = 'resource_pool', id = tostring(pool.id) },
            payload = { poolId = pool.id, poolType = pool.pool_type, label = pool.label },
        })
        return reply(src, false, ('%s ist erschöpft — versuche es woanders.'):format(pool.label))
    end

    -- Ertrag skaliert mit Skill-Level (Nutzung macht besser)
    local level = Skills:GetLevel(ident.characterId, pool.skill)
    local baseYield = Core:TuningGet('resources.base_yield', 1)
    local yield = math.min(pool.current, baseYield + math.floor(level / 3))

    local uuid, err = Inv:Create(pool.item_name, yield, 'resource.harvest',
        { type = 'character', id = ident.characterId },
        { createdBy = ident.characterId, srcForLog = src })
    if not uuid then
        return reply(src, false, err == 'too_heavy' and 'Du kannst nicht mehr tragen.' or 'Abbau fehlgeschlagen.')
    end

    pool.current = pool.current - yield
    Db.update('UPDATE resource_pools SET current = ? WHERE id = ?', { pool.current, pool.id })

    Core:Log(src, 'resource.harvest', {
        target = { kind = 'resource_pool', id = tostring(pool.id) },
        payload = { poolId = pool.id, poolType = pool.pool_type, item = pool.item_name,
                    yield = yield, poolRemaining = pool.current, skillLevel = level },
    })

    Skills:AddXp(ident.characterId, pool.skill, Core:TuningGet('resources.xp_per_harvest', 15), src)
    reply(src, true, ('%dx %s — Bestand hier: %d/%d.'):format(yield, pool.item_name, pool.current, pool.capacity))
end)

-- Regeneration (Intervall + Raten via Tuning/DB)
CreateThread(function()
    while true do
        local minutes = Core:TuningGet('resources.regen_tick_minutes', 10)
        Wait(math.max(1, minutes) * 60000)
        for _, pool in pairs(pools) do
            if pool.current < pool.capacity then
                pool.current = math.min(pool.capacity, pool.current + pool.regen_per_tick)
                Db.update('UPDATE resource_pools SET current = ? WHERE id = ?', { pool.current, pool.id })
            end
        end
    end
end)

