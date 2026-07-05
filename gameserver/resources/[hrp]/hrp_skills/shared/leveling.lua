--[[
    Skill-Level-Formeln — PURE Funktionen (testbar via scripts/test-lua.sh).

    Level = floor(sqrt(xp / 100))  ->  100 XP = Lv1, 400 = Lv2, 2500 = Lv5, 10000 = Lv10
    Kein XP-Kauf: XP entsteht ausschließlich durch Nutzung (AddXp der Module).
    Decay: unbenutzte Skills verlieren pro Tag einen Prozentsatz — Fähigkeiten
    rosten, wie im echten Leben.
]]

HRPLeveling = {}

HRPLeveling.MAX_LEVEL = 20

function HRPLeveling.XpToLevel(xp)
    if xp <= 0 then return 0 end
    return math.min(HRPLeveling.MAX_LEVEL, math.floor(math.sqrt(xp / 100)))
end

function HRPLeveling.XpForLevel(level)
    return level * level * 100
end

--- XP-Decay: ratePerDay (z. B. 0.02 = 2 %/Tag) über daysUnused Tage,
--- aber nie unter die Schwelle des halben aktuellen Levels (kein Totalverlust).
function HRPLeveling.Decay(xp, daysUnused, ratePerDay)
    if daysUnused <= 0 or xp <= 0 then return xp end
    local decayed = xp * ((1 - ratePerDay) ^ daysUnused)
    local level = HRPLeveling.XpToLevel(xp)
    local floorXp = HRPLeveling.XpForLevel(math.floor(level / 2))
    return math.max(math.floor(decayed), floorXp)
end

return HRPLeveling
