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

-- Öffentliche Werkbänke (weitere folgen als Map-/Immobilien-Feature)
local WORKBENCHES = {
    vector3(-322.6, -134.0, 39.0),    -- LS Customs Burton
    vector3(717.7, -1071.5, 22.2),    -- Popular Street
    vector3(1180.3, 2640.1, 37.8),    -- Route 68
}

local function atWorkbench(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, wb in ipairs(WORKBENCHES) do
        if #(pos - wb) <= 5.0 then return true end
    end
    return false
end

--- Werkzeug prüfen + Verschleiß anwenden (Qualität = Haltbarkeit; NULL = 100).
local function useTool(src, characterId, toolItem, wear, correlationId)
    for _, it in ipairs(Inv:GetContainer('character', characterId) or {}) do
        if it.name == toolItem then
            local durability = it.quality or 100
            local remaining = durability - wear
            if remaining <= 0 then
                Inv:Destroy(it.uuid, 'decay.expired', { correlationId = correlationId, srcForLog = src })
                reply(src, false, ('Dein %s ist dabei zu Bruch gegangen!'):format(toolItem))
            else
                Inv:Modify(it.uuid, { quality = remaining }, 'tool.wear',
                    { correlationId = correlationId, srcForLog = src })
            end
            return true
        end
    end
    return false
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

    if recipe.requires_workbench == 1 and not atWorkbench(src) then
        return reply(src, false, 'Dafür brauchst du eine Werkbank (LS Customs Burton, Popular Street, Route 68).')
    end

    local inventory = Inv:GetContainer('character', ident.characterId) or {}
    local ok, plan, missing = HRPCrafting.PlanInputs(recipe.inputs, inventory)
    if not ok then
        return reply(src, false, ('Zutat fehlt: %s. Zutatenliste: /rezepte'):format(missing))
    end

    local correlationId = Logger:NewCorrelationId()

    -- Werkzeug-Pflicht + Verschleiß
    if recipe.tool_item then
        if not useTool(src, ident.characterId, recipe.tool_item, recipe.tool_wear, correlationId) then
            return reply(src, false, ('Werkzeug fehlt: %s.'):format(recipe.tool_item))
        end
    end

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
