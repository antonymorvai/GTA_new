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
check('SNOWLIGHT ist glatt', HRPWeather.IsWet('SNOWLIGHT'))
check('CLEAR ist trocken', not HRPWeather.IsWet('CLEAR'))

print('HRPWeather.SeasonOf / ApplySeason / SeasonFactor')
check('Tag 1 = Winter', HRPWeather.SeasonOf(1) == 'winter')
check('Tag 100 = Frühling', HRPWeather.SeasonOf(100) == 'spring')
check('Tag 200 = Sommer', HRPWeather.SeasonOf(200) == 'summer')
check('Tag 300 = Herbst', HRPWeather.SeasonOf(300) == 'autumn')
check('Tag 360 = Winter', HRPWeather.SeasonOf(360) == 'winter')
check('Winter: Regen wird Schnee', HRPWeather.ApplySeason('RAIN', 'winter') == 'SNOWLIGHT')
check('Winter: Gewitter wird Blizzard', HRPWeather.ApplySeason('THUNDER', 'winter') == 'BLIZZARD')
check('Sommer: Regen bleibt Regen', HRPWeather.ApplySeason('RAIN', 'summer') == 'RAIN')
check('Farming im Winter gedrosselt', HRPWeather.SeasonFactor('farming', 'winter') < 0.5)
check('Farming im Frühling verstärkt', HRPWeather.SeasonFactor('farming', 'spring') > 1.0)
check('Unbekannter Pool-Typ = Faktor 1', HRPWeather.SeasonFactor('unbekannt', 'winter') == 1.0)

if failures > 0 then
    print(('%d Test(s) fehlgeschlagen.'):format(failures))
    os.exit(1)
end
print('Alle Wetter-Tests bestanden.')
