--[[
    Crafting-Logik — PURE Funktionen (testbar via scripts/test-lua.sh).
]]

HRPCrafting = {}

--- Prüft, ob ein Inventar (Liste {name, quantity, uuid}) die Zutaten deckt.
--- Rückgabe: ok, plan — plan = Liste {uuid, take} für den Verbrauch.
function HRPCrafting.PlanInputs(inputs, inventory)
    local plan = {}
    for _, need in ipairs(inputs) do
        local remaining = need.qty
        for _, item in ipairs(inventory) do
            if remaining > 0 and item.name == need.item and item.quantity > 0 then
                local take = math.min(remaining, item.quantity)
                plan[#plan + 1] = { uuid = item.uuid, take = take }
                remaining = remaining - take
            end
        end
        if remaining > 0 then
            return false, nil, need.item
        end
    end
    return true, plan
end

--- Qualität des Ergebnisses: Basis 50, +4 pro Skill-Level über Mindestlevel,
--- gedeckelt bei 100 (Zufallsstreuung fügt der Server hinzu).
function HRPCrafting.BaseQuality(skillLevel, minLevel)
    return math.min(100, 50 + math.max(0, skillLevel - minLevel) * 4)
end

return HRPCrafting
