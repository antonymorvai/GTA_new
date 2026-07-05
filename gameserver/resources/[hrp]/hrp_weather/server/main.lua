--[[
    hrp_weather – server-autoritatives Wetter (Fronten) + synchrone Uhrzeit.

    - Wetter-Tick (Tuning weather.tick_minutes): Zustandsmaschine mit
      plausiblen Übergängen; jeder Wechsel als weather.change geloggt und mit
      sanfter Überblendung an alle Clients verteilt.
    - Zeit: In-Game-Uhr läuft mit Tuning time.scale (In-Game-Minuten pro
      Echtzeit-Minute, Default 4 ≙ 6-h-Tag); ACP-Wetter-Override via
      Tuning weather.override ('' = Automatik).
    - Nasse Fahrbahn: State Bag 'hrp:wet' für Fahrphysik-Effekte (Clients).
]]

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local currentWeather = 'CLEAR'
-- In-Game-Minuten seit Mitternacht (Start: 09:00)
local gameMinutes = 9 * 60

local function broadcastWeather(transitionSec)
    TriggerClientEvent('hrp:weather:set', -1, currentWeather, transitionSec or 45.0)
    GlobalState['hrp:wet'] = HRPWeather.IsWet(currentWeather)
end

local function broadcastTime()
    TriggerClientEvent('hrp:weather:time', -1,
        math.floor(gameMinutes / 60) % 24, math.floor(gameMinutes % 60))
end

-- Neue Spieler sofort synchronisieren
AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(5000)
        TriggerClientEvent('hrp:weather:set', src, currentWeather, 1.0)
        TriggerClientEvent('hrp:weather:time', src,
            math.floor(gameMinutes / 60) % 24, math.floor(gameMinutes % 60))
    end)
end)

-- Wetter-Tick
CreateThread(function()
    Wait(5000)
    broadcastWeather(1.0)
    while true do
        local minutes = Core:TuningGet('weather.tick_minutes', 15)
        Wait(math.max(1, minutes) * 60000)

        local override = Core:TuningGet('weather.override', '')
        local season = Core:TuningGet('weather.season_override', '')
        if season == '' then
            season = HRPWeather.SeasonOf(tonumber(os.date('%j')))
        end

        local nextWeather
        if override ~= '' then
            nextWeather = override
        else
            -- Saison-Mapping rückgängig für die Zustandsmaschine (SNOW -> RAIN)
            local logical = currentWeather
            if logical == 'SNOWLIGHT' then logical = 'RAIN' end
            if logical == 'BLIZZARD' then logical = 'THUNDER' end
            nextWeather = HRPWeather.ApplySeason(HRPWeather.Next(logical, math.random()), season)
        end

        if nextWeather ~= currentWeather then
            Logger:Log('weather.change', {
                payload = { before = currentWeather, after = nextWeather,
                            override = override ~= '' },
            })
            currentWeather = nextWeather
            broadcastWeather(45.0)
        end
    end
end)

-- Zeit-Tick (jede Echtzeit-Minute)
CreateThread(function()
    while true do
        Wait(60000)
        local scale = Core:TuningGet('time.scale', 4)
        gameMinutes = (gameMinutes + scale) % 1440
        broadcastTime()
    end
end)

exports('GetWeather', function() return currentWeather end)
exports('IsWet', function() return HRPWeather.IsWet(currentWeather) end)
exports('GetSeason', function()
    local override = Core:TuningGet('weather.season_override', '')
    if override ~= '' then return override end
    return HRPWeather.SeasonOf(tonumber(os.date('%j')))
end)
exports('SeasonFactor', function(poolType)
    local override = Core:TuningGet('weather.season_override', '')
    local season = override ~= '' and override or HRPWeather.SeasonOf(tonumber(os.date('%j')))
    return HRPWeather.SeasonFactor(poolType, season)
end)
