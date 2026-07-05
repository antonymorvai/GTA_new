--[[
    hrp_logger – zentraler Log-Client (Kernprinzip A).

    Vertrag: exports.hrp_logger:Log(type, data) ist NIE blockierend und darf
    NIE Gameplay-Performance kosten. Events landen in einer In-Memory-Queue,
    werden gebatcht per HTTP an das Backend geschickt (internes Netz) und dort
    über Redis Streams in den Log-Store geschrieben.

    Ausfallsicherheit: Schlägt der Versand fehl, werden Batches als JSON-Lines
    in buffer/pending.jsonl persistiert und nach Wiederverfügbarkeit nachgespielt.
]]

local Config = {
    ingestUrl    = GetConvar('hrp_ingest_url', 'http://backend:3001/v1/ingest/events'),
    ingestToken  = GetConvar('hrp_ingest_token', ''),
    serverId     = GetConvar('hrp_server_id', 'main'),
    flushInterval = 2000,   -- ms
    maxBatch      = 100,
    bufferFile    = 'buffer/pending.jsonl',
    maxBufferLines = 50000, -- Notbremse gegen unbegrenztes Disk-Wachstum
}

local queue = {}
local flushing = false
local backendHealthy = true

-- ---------------------------------------------------------------------------
-- Öffentliche API
-- ---------------------------------------------------------------------------

--- Erzeugt eine Korrelations-ID für zusammengesetzte Transaktionen.
function NewCorrelationId()
    return GenerateUuid()
end

--- Reiht ein Log-Event ein. data-Felder (alle optional außer payload-Inhalt):
---   actor = {accountId, characterId, sessionId}
---   target = {kind, id}
---   pos = {x, y, z} | instance = string
---   correlationId = string
---   payload = table (typ-spezifisch, siehe docs/log-event-catalog.md)
function Log(eventType, data)
    data = data or {}
    queue[#queue + 1] = {
        eventId = GenerateUuid(),
        ts = os.time() * 1000 + math.floor((GetGameTimer() % 1000)),
        type = eventType,
        schemaVersion = 1,
        serverId = Config.serverId,
        actor = data.actor,
        target = data.target,
        context = (data.pos or data.instance) and { pos = data.pos, instance = data.instance } or nil,
        correlationId = data.correlationId,
        payload = data.payload or {},
    }
end

exports('Log', Log)
exports('NewCorrelationId', NewCorrelationId)
exports('IsHealthy', function() return backendHealthy end)

-- ---------------------------------------------------------------------------
-- Versand
-- ---------------------------------------------------------------------------

local function postBatch(events, cb)
    PerformHttpRequest(Config.ingestUrl, function(status)
        cb(status == 200 or status == 201 or status == 204)
    end, 'POST', json.encode({ events = events }), {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. Config.ingestToken,
    })
end

local function bufferAppend(events)
    local existing = LoadResourceFile(GetCurrentResourceName(), Config.bufferFile) or ''
    local _, lineCount = existing:gsub('\n', '')
    if lineCount >= Config.maxBufferLines then
        print(('^1[hrp_logger] Disk-Buffer voll (%d Zeilen) – Events werden verworfen! Backend prüfen.^0'):format(lineCount))
        return
    end
    local lines = {}
    for _, ev in ipairs(events) do
        lines[#lines + 1] = json.encode(ev)
    end
    SaveResourceFile(GetCurrentResourceName(), Config.bufferFile, existing .. table.concat(lines, '\n') .. '\n', -1)
end

local function bufferDrain()
    local content = LoadResourceFile(GetCurrentResourceName(), Config.bufferFile)
    if not content or content == '' then return end

    local events = {}
    for line in content:gmatch('[^\n]+') do
        local ok, ev = pcall(json.decode, line)
        if ok and ev then events[#events + 1] = ev end
    end
    if #events == 0 then
        SaveResourceFile(GetCurrentResourceName(), Config.bufferFile, '', -1)
        return
    end

    -- In Batches nachspielen; bei erneutem Fehler bleibt der Rest im Buffer.
    local idx = 1
    local function sendNext()
        if idx > #events then
            SaveResourceFile(GetCurrentResourceName(), Config.bufferFile, '', -1)
            print(('^2[hrp_logger] Disk-Buffer nachgespielt (%d Events).^0'):format(#events))
            return
        end
        local batch = {}
        for i = idx, math.min(idx + Config.maxBatch - 1, #events) do
            batch[#batch + 1] = events[i]
        end
        postBatch(batch, function(ok)
            if not ok then return end -- Rest bleibt im Buffer, nächster Drain-Versuch später
            idx = idx + #batch
            sendNext()
        end)
    end
    sendNext()
end

local function flush()
    if flushing or #queue == 0 then return end
    flushing = true

    local batch = {}
    local n = math.min(#queue, Config.maxBatch)
    for i = 1, n do batch[i] = queue[i] end
    -- Rest der Queue nachrücken
    local rest = {}
    for i = n + 1, #queue do rest[#rest + 1] = queue[i] end
    queue = rest

    postBatch(batch, function(ok)
        if ok then
            if not backendHealthy then
                backendHealthy = true
                bufferDrain()
            end
        else
            backendHealthy = false
            bufferAppend(batch)
        end
        flushing = false
    end)
end

CreateThread(function()
    if Config.ingestToken == '' then
        print('^1[hrp_logger] FATAL: hrp_ingest_token nicht gesetzt – Logging inaktiv wäre ein DoD-Verstoß. Server prüfen!^0')
    end
    -- Beim Start eventuell liegengebliebenen Buffer nachspielen
    Wait(5000)
    bufferDrain()
    while true do
        Wait(Config.flushInterval)
        flush()
    end
end)

-- Ressourcen-Lifecycle selbst loggen (system.*)
AddEventHandler('onResourceStart', function(res)
    Log('system.resource_start', { payload = { resource = res } })
end)
AddEventHandler('onResourceStop', function(res)
    Log('system.resource_stop', { payload = { resource = res } })
    if res == GetCurrentResourceName() then
        -- letzter synchroner Flush-Versuch; Rest sichert der Disk-Buffer
        flush()
    end
end)
