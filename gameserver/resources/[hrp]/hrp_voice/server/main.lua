--[[
    hrp_voice – Funk mit Frequenzen:
    - Funkgerät-Item nötig; /funk <frequenz> tritt bei, /funkaus verlässt.
    - Frequenzen 1–9 sind VERSCHLÜSSELTE Staatskanäle (nur Polizei/EMS im Dienst).
    - SaltyChat-Brücke: wenn die saltychat-Ressource läuft, wird der echte
      Voice-Kanal gesetzt (pcall); ohne Voice läuft Text-Funk (/f <text>).
    - Logging: comms.radio — Metadaten immer, Text-Funk mit Inhalt (Katalog §2.2).
]]

local Core = exports.hrp_core
local Inv = exports.hrp_inventory
local Jobs = exports.hrp_jobs

-- channels[frequenz] = { [src] = true }
local channels = {}
local tuned = {}   -- tuned[src] = frequenz

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2FUNK' or '^1FUNK', msg } })
end

local function hasRadio(characterId)
    for _, it in ipairs(Inv:GetContainer('character', characterId) or {}) do
        if it.name == 'radio' then return true end
    end
    return false
end

local function isStateDuty(characterId)
    local ok, job = pcall(function() return Jobs:GetJob(characterId) end)
    return ok and job and job.is_state == 1 and job.on_duty == 1
end

local function leave(src, silent)
    local freq = tuned[src]
    if not freq then return end
    if channels[freq] then channels[freq][src] = nil end
    tuned[src] = nil
    pcall(function() exports.saltychat:SetRadioChannel(src, '') end)
    Core:Log(src, 'comms.radio', { payload = { action = 'leave', frequency = freq } })
    if not silent then reply(src, true, 'Funkgerät aus.') end
end

Core:RegisterSecureEvent('hrp:voice:tune', {
    rate = 0.5, burst = 2,
    schema = { { type = 'number', min = 1, max = 999.9 } },
}, function(src, frequency)
    local ident = Core:GetPlayerIdentity(src)
    if not hasRadio(ident.characterId) then return reply(src, false, 'Du hast kein Funkgerät.') end

    frequency = math.floor(frequency * 10) / 10
    if frequency < 10 and not isStateDuty(ident.characterId) then
        Core:Log(src, 'comms.radio', {
            payload = { action = 'denied', frequency = frequency, reason = 'encrypted_state_channel' },
        })
        return reply(src, false, 'Frequenzen 1–9 sind verschlüsselte Staatskanäle.')
    end

    leave(src, true)
    channels[frequency] = channels[frequency] or {}
    channels[frequency][src] = true
    tuned[src] = frequency

    pcall(function() exports.saltychat:SetRadioChannel(src, tostring(frequency)) end)
    Core:Log(src, 'comms.radio', { payload = { action = 'join', frequency = frequency } })
    reply(src, true, ('Frequenz %.1f MHz eingestellt.'):format(frequency))
end)

Core:RegisterSecureEvent('hrp:voice:off', { rate = 0.5, burst = 2 }, function(src)
    leave(src)
end)

-- Text-Funk (Fallback ohne Voice; mit SaltyChat weiterhin als "Funkspruch-Log" nutzbar)
Core:RegisterSecureEvent('hrp:voice:transmit', {
    rate = 1, burst = 3,
    schema = { { type = 'string', maxLen = 200 } },
}, function(src, message)
    local freq = tuned[src]
    if not freq then return reply(src, false, 'Kein Kanal eingestellt (/funk <frequenz>).') end

    Core:Log(src, 'comms.radio', {
        payload = { action = 'transmit', frequency = freq, body = message },
    })
    for member in pairs(channels[freq] or {}) do
        TriggerClientEvent('chat:addMessage', member, {
            args = { ('^2📻 %.1f MHz'):format(freq), message },
        })
    end
end)

-- Funkgerät weg = Kanal weg
AddEventHandler('hrp:inventory:instanceMoved', function()
    for src, freq in pairs(tuned) do
        local ident = Core:GetPlayerIdentity(src)
        if ident and ident.characterId and not hasRadio(ident.characterId) then
            leave(src, true)
            reply(src, false, 'Dein Funkgerät ist weg — Verbindung tot.')
        end
    end
end)

AddEventHandler('playerDropped', function()
    leave(source, true)
end)
