-- Unit-Tests: Crafting-Zutatenplanung und Qualitätsformel.

dofile('gameserver/resources/[hrp]/hrp_crafting/shared/crafting.lua')

local failures = 0
local function check(name, condition, detail)
    if condition then print(('  PASS  %s'):format(name))
    else failures = failures + 1 print(('  FAIL  %s%s'):format(name, detail and (' — ' .. detail) or '')) end
end

print('HRPCrafting.PlanInputs')

local inventory = {
    { uuid = 'a', name = 'cloth', quantity = 1 },
    { uuid = 'b', name = 'cloth', quantity = 3 },
    { uuid = 'c', name = 'metal_parts', quantity = 2 },
}

-- Zutaten über mehrere Instanzen hinweg einsammeln
local ok, plan = HRPCrafting.PlanInputs({ { item = 'cloth', qty = 3 } }, inventory)
check('deckt Bedarf über Instanzen hinweg', ok)
check('Plan nimmt zuerst Instanz a (1) dann b (2)',
    plan[1].uuid == 'a' and plan[1].take == 1 and plan[2].uuid == 'b' and plan[2].take == 2)

-- Mehrere Zutaten
local ok2 = HRPCrafting.PlanInputs(
    { { item = 'cloth', qty = 2 }, { item = 'metal_parts', qty = 2 } }, inventory)
check('mehrere Zutaten gleichzeitig', ok2)

-- Fehlende Zutat wird benannt
local ok3, _, missing = HRPCrafting.PlanInputs({ { item = 'gold', qty = 1 } }, inventory)
check('fehlende Zutat schlägt fehl', not ok3)
check('fehlende Zutat wird benannt', missing == 'gold')

-- Zu wenig Menge
local ok4 = HRPCrafting.PlanInputs({ { item = 'metal_parts', qty = 5 } }, inventory)
check('zu geringe Menge schlägt fehl', not ok4)

-- Leeres Inventar
local ok5 = HRPCrafting.PlanInputs({ { item = 'cloth', qty = 1 } }, {})
check('leeres Inventar schlägt fehl', not ok5)

print('HRPCrafting.BaseQuality')
check('Mindestlevel ergibt Basis 50', HRPCrafting.BaseQuality(2, 2) == 50)
check('höheres Level erhöht Qualität', HRPCrafting.BaseQuality(7, 2) == 70)
check('Deckel bei 100', HRPCrafting.BaseQuality(50, 0) == 100)
check('Level unter Mindestlevel bleibt Basis', HRPCrafting.BaseQuality(0, 3) == 50)

if failures > 0 then
    print(('%d Test(s) fehlgeschlagen.'):format(failures))
    os.exit(1)
end
print('Alle Crafting-Tests bestanden.')
