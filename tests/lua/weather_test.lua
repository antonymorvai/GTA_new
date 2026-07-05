-- Unit-Tests: Wetter-Zustandsmaschine (Fronten, keine unplausiblen Sprünge).

dofile('gameserver/resources/[hrp]/hrp_weather/shared/weather.lua')

local failures = 0
local function check(name, condition, detail)
    if condition then print(('  PASS  %s'):format(name))
    else failures = failures + 1 print(('  FAIL  %s%s'):format(name, detail and (' — ' .. detail) or '')) end
end

print('HRPWeather.Next')

-- Determinismus: gleicher Wurf -> gleiches Ergebnis
check('deterministisch bei gleichem Wurf',
    HRPWeather.Next('CLEAR', 0.5) == HRPWeather.Next('CLEAR', 0.5))

-- Alle Ergebnisse liegen in der Übergangstabelle des Ausgangszustands
local function reachable(state)
    local valid = {}
    for _, opt in ipairs(HRPWeather.TRANSITIONS[state]) do valid[opt[1]] = true end
    for roll = 0, 99 do
        local result = HRPWeather.Next(state, roll / 100)
        if not valid[result] then return false, result end
    end
    return true
end
for state in pairs(HRPWeather.TRANSITIONS) do
    local ok, bad = reachable(state)
    check(('nur plausible Übergänge aus %s'):format(state), ok, bad and ('unerlaubt: ' .. bad))
end

-- Kein direkter Sprung CLEAR -> THUNDER (Fronten-Prinzip)
local jumps = false
for roll = 0, 99 do
    if HRPWeather.Next('CLEAR', roll / 100) == 'THUNDER' then jumps = true end
end
check('kein Sprung CLEAR -> THUNDER', not jumps)

-- Unbekannter Zustand fällt sicher auf CLEAR-Übergänge zurück
check('unbekannter Zustand crasht nicht', HRPWeather.Next('KAPUTT', 0.5) ~= nil)

print('HRPWeather.IsWet')
check('RAIN ist nass', HRPWeather.IsWet('RAIN'))
check('THUNDER ist nass', HRPWeather.IsWet('THUNDER'))
check('CLEAR ist trocken', not HRPWeather.IsWet('CLEAR'))

if failures > 0 then
    print(('%d Test(s) fehlgeschlagen.'):format(failures))
    os.exit(1)
end
print('Alle Wetter-Tests bestanden.')
