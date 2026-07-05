--[[
    Event-Security (server-autoritativ):
    - Whitelisting: Nur über HRP.RegisterSecureEvent registrierte Events existieren.
    - Schema-Validierung: Jedes Argument wird gegen ein deklariertes Schema geprüft.
    - Rate-Limiting: Token-Bucket pro Spieler+Event.
    - Session-Bindung: Events ohne gültige Session werden verworfen.
    Jeder Verstoß erzeugt ein security.*-Event im Log-Store.
]]

local buckets = {}   -- buckets[src][event] = {tokens, lastRefill}

local function checkRate(src, eventName, perSec, burst)
    buckets[src] = buckets[src] or {}
    local b = buckets[src][eventName]
    local now = GetGameTimer()
    if not b then
        b = { tokens = burst, last = now }
        buckets[src][eventName] = b
    end
    local elapsed = (now - b.last) / 1000.0
    b.tokens = math.min(burst, b.tokens + elapsed * perSec)
    b.last = now
    if b.tokens >= 1 then
        b.tokens = b.tokens - 1
        return true
    end
    return false
end

-- Schema-Prüfung: {name = {type='string'|'number'|'table'|'boolean', min=, max=, maxLen=, pattern=, optional=}}
local function validateArg(spec, value)
    if value == nil then
        return spec.optional == true, 'missing'
    end
    if type(value) ~= spec.type then return false, 'type' end
    if spec.type == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then return false, 'nan' end
        if spec.min and value < spec.min then return false, 'min' end
        if spec.max and value > spec.max then return false, 'max' end
        if spec.integer and value % 1 ~= 0 then return false, 'integer' end
    elseif spec.type == 'string' then
        if spec.maxLen and #value > spec.maxLen then return false, 'maxLen' end
        if spec.pattern and not value:match(spec.pattern) then return false, 'pattern' end
    end
    return true
end

--- Registriert ein abgesichertes, vom Client aufrufbares Event.
--- opts = {
---   rate = Events/Sekunde (Default 2), burst = Bucket-Größe (Default 5),
---   schema = { {type=..., ...}, ... }  -- positionsbasiert je Argument
---   requireCharacter = true|false      -- Default true
---   permission = 'game.admin.x'        -- optionale RBAC-Anforderung
--- }
function HRP.RegisterSecureEvent(eventName, opts, handler)
    opts = opts or {}
    local rate = opts.rate or 2
    local burst = opts.burst or 5
    local requireCharacter = opts.requireCharacter ~= false

    RegisterNetEvent(eventName, function(...)
        local src = source
        local p = HRP.Players[src]

        -- Session-Bindung
        if not p then
            return -- Verbindung ohne abgeschlossenen Connect-Flow: still verwerfen
        end
        if requireCharacter and not p.characterId then
            HRP.Log(src, 'security.invalid_event', {
                payload = { eventName = eventName, violation = 'no_character' },
            })
            return
        end

        -- Rate-Limit
        if not checkRate(src, eventName, rate, burst) then
            HRP.Log(src, 'security.rate_limit', {
                payload = { eventName = eventName, allowedPerSec = rate },
            })
            return
        end

        -- RBAC
        if opts.permission and not HRP.HasPermission(src, opts.permission) then
            HRP.Log(src, 'security.invalid_event', {
                payload = { eventName = eventName, violation = 'permission:' .. opts.permission },
            })
            return
        end

        -- Argument-Schema
        if opts.schema then
            local args = { ... }
            for i, spec in ipairs(opts.schema) do
                local ok, why = validateArg(spec, args[i])
                if not ok then
                    HRP.Log(src, 'security.invalid_event', {
                        payload = { eventName = eventName, violation = ('arg%d:%s'):format(i, why) },
                    })
                    return
                end
            end
        end

        handler(src, ...)
    end)
end

AddEventHandler('playerDropped', function()
    buckets[source] = nil
end)

-- Für andere Ressourcen (Handler-Funktionen sind cross-resource aufrufbar)
exports('RegisterSecureEvent', function(eventName, opts, handler)
    HRP.RegisterSecureEvent(eventName, opts, handler)
end)
