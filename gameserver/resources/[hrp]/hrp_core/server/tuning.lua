--[[
    Live-Tuning / Feature-Flags (Kernprinzip B):
    Balancing-Werte sind Daten in config_flags — zur Laufzeit änderbar ohne
    Restart, jede Änderung versioniert (config_flag_history) und als
    config.change-Event geloggt. Rollback = alten Wert erneut setzen.

    Nutzung in Modulen:  local v = exports.hrp_core:TuningGet('economy.price_tick_minutes', 15)
    Werte werden hier zentral gecacht; Module lesen bei jeder Nutzung (billig).
]]

HRP.Tuning = {}

local cache = {}
local loaded = false

local function loadAll()
    cache = {}
    for _, row in ipairs(Db.query('SELECT flag_key, flag_value FROM config_flags') or {}) do
        local ok, value = pcall(json.decode, row.flag_value)
        if ok then cache[row.flag_key] = value end
    end
    loaded = true
    print(('[hrp_core] %d Tuning-Flags geladen.'):format(#(Db.query('SELECT flag_key FROM config_flags') or {})))
end

MySQL.ready(function()
    loadAll()
    -- Periodischer Reload: übernimmt ACP-Änderungen (config_flags via Backend)
    -- ohne Restart. Intervall bewusst kurz — die Query ist trivial.
    CreateThread(function()
        while true do
            Wait(60000)
            loadAll()
        end
    end)
end)

--- Wert lesen; default wird beim ersten Zugriff persistiert, damit JEDER
--- aktive Balancing-Wert im ACP sichtbar und änderbar ist (DoD-Regel 3).
function HRP.Tuning.Get(key, default)
    if not loaded then return default end
    local v = cache[key]
    if v ~= nil then return v end
    if default ~= nil then
        cache[key] = default
        Db.insert(
            'INSERT IGNORE INTO config_flags (flag_key, flag_value, description) VALUES (?, ?, ?)',
            { key, json.encode(default), 'auto-registriert (Default)' }
        )
    end
    return default
end

--- Wert setzen: Cache + DB + Historie + config.change-Event.
function HRP.Tuning.Set(key, value, byAccountId)
    local old = cache[key]
    cache[key] = value

    Db.update([[
        INSERT INTO config_flags (flag_key, flag_value, updated_by) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE flag_value = VALUES(flag_value), updated_by = VALUES(updated_by)
    ]], { key, json.encode(value), byAccountId })
    Db.insert(
        'INSERT INTO config_flag_history (flag_key, old_value, new_value, changed_by) VALUES (?, ?, ?, ?)',
        { key, old ~= nil and json.encode(old) or nil, json.encode(value), byAccountId })

    exports.hrp_logger:Log('config.change', {
        actor = byAccountId and { accountId = byAccountId } or nil,
        target = { kind = 'config_flag', id = key },
        payload = { key = key, before = old, after = value },
    })

    TriggerEvent('hrp:core:tuningChanged', key, value)
    return true
end

exports('TuningGet', function(key, default) return HRP.Tuning.Get(key, default) end)
exports('TuningSet', function(key, value, byAccountId) return HRP.Tuning.Set(key, value, byAccountId) end)

-- Konsole (txAdmin): hrp_tuning_set <key> <json>  |  hrp_tuning_get <key>
RegisterCommand('hrp_tuning_set', function(src, args, raw)
    if src ~= 0 then return end
    local key = args[1]
    local jsonValue = raw:sub(#('hrp_tuning_set ' .. key) + 2)
    if not key or jsonValue == '' then
        print('Usage: hrp_tuning_set <key> <json>   z. B. hrp_tuning_set economy.price_tick_minutes 10')
        return
    end
    local ok, value = pcall(json.decode, jsonValue)
    if not ok then print('Ungültiges JSON: ' .. jsonValue) return end
    HRP.Tuning.Set(key, value, nil)
    print(('OK: %s = %s'):format(key, jsonValue))
end, true)

RegisterCommand('hrp_tuning_get', function(src, args)
    if src ~= 0 then return end
    if not args[1] then print('Usage: hrp_tuning_get <key>') return end
    print(('%s = %s'):format(args[1], json.encode(cache[args[1]])))
end, true)
