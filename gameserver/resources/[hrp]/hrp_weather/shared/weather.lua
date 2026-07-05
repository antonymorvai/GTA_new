--[[
    Wetter-Zustandsmaschine mit FRONTEN statt Zufalls-Switch — PURE Funktionen.
    Wetter entwickelt sich nur entlang plausibler Übergänge (klar wird nicht
    schlagartig zum Gewitter); Regenphasen klingen über CLEARING ab.
]]

HRPWeather = {}

-- Übergänge: aktueller Zustand -> gewichtete Folgezustände
HRPWeather.TRANSITIONS = {
    CLEAR      = { { 'CLEAR', 55 }, { 'EXTRASUNNY', 20 }, { 'CLOUDS', 25 } },
    EXTRASUNNY = { { 'EXTRASUNNY', 60 }, { 'CLEAR', 40 } },
    CLOUDS     = { { 'CLOUDS', 40 }, { 'CLEAR', 25 }, { 'OVERCAST', 35 } },
    OVERCAST   = { { 'OVERCAST', 35 }, { 'CLOUDS', 30 }, { 'RAIN', 25 }, { 'FOGGY', 10 } },
    FOGGY      = { { 'FOGGY', 40 }, { 'OVERCAST', 40 }, { 'CLOUDS', 20 } },
    RAIN       = { { 'RAIN', 35 }, { 'THUNDER', 20 }, { 'CLEARING', 45 } },
    THUNDER    = { { 'THUNDER', 30 }, { 'RAIN', 40 }, { 'CLEARING', 30 } },
    CLEARING   = { { 'CLEARING', 25 }, { 'CLOUDS', 45 }, { 'CLEAR', 30 } },
}

--- Nächstes Wetter für einen Wurf roll ∈ [0,1). Deterministisch testbar.
function HRPWeather.Next(current, roll)
    local options = HRPWeather.TRANSITIONS[current] or HRPWeather.TRANSITIONS.CLEAR
    local total = 0
    for _, opt in ipairs(options) do total = total + opt[2] end
    local target = roll * total
    local acc = 0
    for _, opt in ipairs(options) do
        acc = acc + opt[2]
        if target < acc then return opt[1] end
    end
    return options[#options][1]
end

--- Ist der Zustand Teil einer Regen-/Schneefront? (Glätte-/Verbrauchs-Effekte)
function HRPWeather.IsWet(state)
    return state == 'RAIN' or state == 'THUNDER' or state == 'CLEARING'
        or state == 'SNOWLIGHT' or state == 'BLIZZARD'
end

--- Jahreszeit aus dem Tag des Jahres (1..366).
function HRPWeather.SeasonOf(dayOfYear)
    if dayOfYear >= 80 and dayOfYear < 172 then return 'spring' end
    if dayOfYear >= 172 and dayOfYear < 264 then return 'summer' end
    if dayOfYear >= 264 and dayOfYear < 355 then return 'autumn' end
    return 'winter'
end

--- Saison-Anpassung des Zustands: Im Winter fällt Niederschlag als Schnee.
function HRPWeather.ApplySeason(state, season)
    if season == 'winter' then
        if state == 'RAIN' then return 'SNOWLIGHT' end
        if state == 'THUNDER' then return 'BLIZZARD' end
    end
    return state
end

--- Erntefaktor pro Pool-Typ und Saison (Regenerations-Multiplikator).
HRPWeather.SEASON_FACTORS = {
    farming = { spring = 1.25, summer = 1.0, autumn = 0.75, winter = 0.25 },
    fishing = { spring = 1.0,  summer = 1.2, autumn = 1.0,  winter = 0.6 },
    logging = { spring = 1.0,  summer = 1.0, autumn = 1.1,  winter = 0.8 },
    mining  = { spring = 1.0,  summer = 1.0, autumn = 1.0,  winter = 1.0 },
    hunting = { spring = 0.8,  summer = 1.0, autumn = 1.3,  winter = 0.7 },
}

function HRPWeather.SeasonFactor(poolType, season)
    local byType = HRPWeather.SEASON_FACTORS[poolType]
    return (byType and byType[season]) or 1.0
end

return HRPWeather
