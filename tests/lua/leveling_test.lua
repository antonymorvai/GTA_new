-- Unit-Tests für die Skill-Level-Formeln (XP nur durch Nutzung, Decay).

dofile('gameserver/resources/[hrp]/hrp_skills/shared/leveling.lua')

local failures = 0
local function check(name, condition, detail)
    if condition then
        print(('  PASS  %s'):format(name))
    else
        failures = failures + 1
        print(('  FAIL  %s%s'):format(name, detail and (' — ' .. detail) or ''))
    end
end

print('HRPLeveling.XpToLevel')
check('0 XP = Level 0', HRPLeveling.XpToLevel(0) == 0)
check('99 XP = Level 0', HRPLeveling.XpToLevel(99) == 0)
check('100 XP = Level 1', HRPLeveling.XpToLevel(100) == 1)
check('400 XP = Level 2', HRPLeveling.XpToLevel(400) == 2)
check('2500 XP = Level 5', HRPLeveling.XpToLevel(2500) == 5)
check('10000 XP = Level 10', HRPLeveling.XpToLevel(10000) == 10)
check('Max-Level-Deckel greift', HRPLeveling.XpToLevel(10 ^ 9) == HRPLeveling.MAX_LEVEL)

print('HRPLeveling.XpForLevel')
check('Umkehrfunktion konsistent', HRPLeveling.XpToLevel(HRPLeveling.XpForLevel(7)) == 7)

print('HRPLeveling.Decay')
check('Kein Decay bei 0 Tagen', HRPLeveling.Decay(1000, 0, 0.02) == 1000)
check('Decay reduziert XP', HRPLeveling.Decay(1000, 5, 0.02) < 1000)
check('Decay ist monoton in Tagen',
    HRPLeveling.Decay(1000, 10, 0.02) < HRPLeveling.Decay(1000, 2, 0.02))
-- Boden: nie unter das halbe Level (Level 10 -> Boden = XP für Level 5 = 2500)
check('Decay-Boden schützt halbes Level', HRPLeveling.Decay(10000, 1000, 0.05) >= 2500,
    'ist ' .. HRPLeveling.Decay(10000, 1000, 0.05))
check('0 XP bleibt 0', HRPLeveling.Decay(0, 10, 0.02) == 0)

if failures > 0 then
    print(('%d Test(s) fehlgeschlagen.'):format(failures))
    os.exit(1)
end
print('Alle Leveling-Tests bestanden.')
