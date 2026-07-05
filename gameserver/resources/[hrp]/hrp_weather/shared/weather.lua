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

--- Ist der Zustand Teil einer Regenfront? (Glätte-/Verbrauchs-Effekte)
function HRPWeather.IsWet(state)
    return state == 'RAIN' or state == 'THUNDER' or state == 'CLEARING'
end

return HRPWeather
