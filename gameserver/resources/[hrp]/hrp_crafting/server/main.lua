--[[
    hrp_crafting – Rezepte sind DB-Daten mit Skill-Freischaltung.
    /rezepte zeigt verfügbare, /craft <name> fertigt: Zutaten werden über
    Instanzen hinweg eingesammelt (item.consume), das Ergebnis entsteht mit
    Skill-abhängiger Qualität (item.create reason 'craft'), alles unter EINER
    correlationId + craft.complete-Event. Skill-XP nur bei Erfolg.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end

local Core = exports.hrp_core
local Inv = exports.hrp_inventory
local Skills = exports.hrp_skills
local Logger = exports.hrp_logger

local recipes = {}

local function loadRecipes()
    recipes = {}
    for _, row in ipairs(Db.query('SELECT * FROM crafting_recipes WHERE active = 1') or {}) do
        row.inputs = json.decode(row.inputs)
        recipes[row.name] = row
    end
end
MySQL.ready(loadRecipes)
RegisterCommand('hrp_crafting_reload', function(src) if src == 0 then loadRecipes() end end, true)

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2WERKBANK' or '^1WERKBANK', msg } })
end

RegisterCommand('rezepte', function(src)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end

    for name, recipe in pairs(recipes) do
        local level = Skills:GetLevel(ident.characterId, recipe.skill)
        local unlocked = level >= recipe.min_level
        local parts = {}
        for _, input in ipairs(recipe.inputs) do
            parts[#parts + 1] = ('%dx %s'):format(input.qty, input.item)
        end
        reply(src, unlocked, ('%s /craft %s — %s (braucht %s Lv %d%s)'):format(
            unlocked and '✓' or '✗', name, recipe.label,
            recipe.skill, recipe.min_level, unlocked and '' or (', du: ' .. level))
            .. ' · Zutaten: ' .. table.concat(parts, ', '))
    end
end, false)

RegisterCommand('craft', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end

    local recipe = args[1] and recipes[args[1]:lower()]
    if not recipe then return reply(src, false, 'Unbekanntes Rezept. Übersicht: /rezepte') end

    local level = Skills:GetLevel(ident.characterId, recipe.skill)
    if level < recipe.min_level then
        return reply(src, false, ('Dafür brauchst du %s Level %d (du: %d).')
            :format(recipe.skill, recipe.min_level, level))
    end

    local inventory = Inv:GetContainer('character', ident.characterId) or {}
    local ok, plan, missing = HRPCrafting.PlanInputs(recipe.inputs, inventory)
    if not ok then
        return reply(src, false, ('Zutat fehlt: %s. Zutatenliste: /rezepte'):format(missing))
    end

    local correlationId = Logger:NewCorrelationId()

    -- Zutaten verbrauchen (über Instanzen hinweg)
    for _, step in ipairs(plan) do
        local consumed = Inv:Consume(step.uuid, step.take, { correlationId = correlationId, srcForLog = src })
        if not consumed then
            return reply(src, false, 'Fertigung fehlgeschlagen (Zutaten-Zugriff).')
        end
    end

    -- Ergebnis mit Skill-Qualität + Streuung
    local quality = math.min(100, HRPCrafting.BaseQuality(level, recipe.min_level) + math.random(0, 10))
    local uuid, err = Inv:Create(recipe.output_item, recipe.output_qty, 'craft',
        { type = 'character', id = ident.characterId },
        { createdBy = ident.characterId, quality = quality,
          correlationId = correlationId, srcForLog = src })
    if not uuid then
        return reply(src, false, err == 'too_heavy' and 'Du kannst das Ergebnis nicht tragen.' or 'Fertigung fehlgeschlagen.')
    end

    Core:Log(src, 'craft.complete', {
        target = { kind = 'item', id = uuid },
        correlationId = correlationId,
        payload = { recipe = recipe.name, output = recipe.output_item,
                    quantity = recipe.output_qty, quality = quality, skillLevel = level },
    })
    Skills:AddXp(ident.characterId, recipe.skill, recipe.xp_reward, src)
    reply(src, true, ('%dx %s hergestellt (Qualität %d%%).'):format(recipe.output_qty, recipe.label, quality))
end, false)
