--[[
    hrp_police – MDT-Datenbasis (Personen-/Fahrzeugakten, Strafregister,
    Fahndungen) und Beweismittelkette (Chain of Custody).

    Wichtig: JEDER MDT-Zugriff (auch reines Nachschlagen) erzeugt ein
    police.mdt_access-Event — der In-RP-Spiegel des ACP-Access-Logs.
    Die Beweismittelkette spiegelt den Item-Trace: Beweise liegen als
    Item-Instanzen im Container 'evidence:<fallnummer>'; jede Ein-/Auslagerung
    erzeugt item.move + evidence.custody + evidence_log-Zeile.

    Das MDT-NUI folgt in Phase 5 (gleiche Datenbasis); bis dahin Befehle.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs
local Inv = exports.hrp_inventory

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^4LSPD' or '^1LSPD', msg } })
end

local function officer(src, minGrade)
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return nil end
    local job = Jobs:GetJob(ident.characterId)
    if not job or job.name ~= 'police' or job.on_duty ~= 1 then return nil end
    if minGrade and job.grade < minGrade then return nil end
    return ident, job
end

local function findCharacterByName(firstName, lastName)
    return Db.single([[
        SELECT id, first_name, last_name, date_of_birth FROM characters
        WHERE first_name = ? AND last_name = ? AND deleted_at IS NULL
    ]], { firstName, lastName })
end

local function logMdtAccess(src, ident, view, targetCharacterId, query)
    Core:Log(src, 'police.mdt_access', {
        target = targetCharacterId and { kind = 'character', id = tostring(targetCharacterId) } or nil,
        payload = { view = view, officerCharacterId = ident.characterId,
                    targetCharacterId = targetCharacterId, query = query },
    })
end

-- ---------------------------------------------------------------------------
-- MDT: Personenakte / Fahrzeugabfrage
-- ---------------------------------------------------------------------------

-- /mdt <vorname> <nachname>
RegisterCommand('mdt', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    if not args[1] or not args[2] then return reply(src, false, 'Nutzung: /mdt <vorname> <nachname>') end

    local char = findCharacterByName(args[1], args[2])
    logMdtAccess(src, ident, 'person', char and char.id or nil, args[1] .. ' ' .. args[2])
    if not char then return reply(src, false, 'Keine Person mit diesem Namen registriert.') end

    reply(src, true, ('— Akte: %s %s (geb. %s) —'):format(char.first_name, char.last_name, tostring(char.date_of_birth):sub(1, 10)))

    local warrants = Db.query("SELECT id, reason FROM warrants WHERE character_id = ? AND status = 'active'", { char.id }) or {}
    for _, w in ipairs(warrants) do
        reply(src, false, ('FAHNDUNG #%d: %s'):format(w.id, w.reason))
    end

    local records = Db.query([[
        SELECT cr.law_code, l.title, cr.created_at FROM criminal_records cr
        LEFT JOIN laws l ON l.code = cr.law_code
        WHERE cr.character_id = ? ORDER BY cr.created_at DESC LIMIT 10
    ]], { char.id }) or {}
    if #records == 0 and #warrants == 0 then
        reply(src, true, 'Keine Einträge im Strafregister.')
    end
    for _, r in ipairs(records) do
        reply(src, true, ('%s — %s (%s)'):format(r.law_code, r.title or '?', tostring(r.created_at):sub(1, 10)))
    end

    local fines = Db.scalar("SELECT COALESCE(SUM(amount),0) FROM fines WHERE character_id = ? AND status = 'open'", { char.id })
    if fines and fines > 0 then
        reply(src, true, ('Offene Bußgelder: %s $'):format(string.format('%.2f', fines / 100)))
    end
end, false)

-- /platecheck <kennzeichen>
RegisterCommand('platecheck', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local plate = table.concat(args, ' '):upper():sub(1, 8)
    if plate == '' then return reply(src, false, 'Nutzung: /platecheck <kennzeichen>') end

    local veh = Db.single([[
        SELECT v.plate, m.label, c.first_name, c.last_name
        FROM vehicles v
        JOIN vehicle_models m ON m.id = v.model_id
        JOIN characters c ON c.id = v.owner_id
        WHERE v.plate = ? AND v.deleted_at IS NULL
    ]], { plate })
    logMdtAccess(src, ident, 'vehicle', nil, plate)
    if not veh then return reply(src, false, 'Kennzeichen nicht registriert.') end
    reply(src, true, ('%s: %s · Halter: %s %s'):format(veh.plate, veh.label, veh.first_name, veh.last_name))
end, false)

-- ---------------------------------------------------------------------------
-- Strafregister & Fahndung
-- ---------------------------------------------------------------------------

-- /charge <serverId> <lawCode> [notiz...]
RegisterCommand('charge', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local targetSrc, lawCode = tonumber(args[1]), args[2]
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end

    local law = Db.single('SELECT code, title FROM laws WHERE code = ? AND active = 1', { lawCode })
    if not law then return reply(src, false, 'Unbekannter Gesetzes-Code. Siehe /laws') end

    local note = table.concat(args, ' ', 3)
    Db.insert([[
        INSERT INTO criminal_records (character_id, law_code, officer_character_id, note)
        VALUES (?, ?, ?, ?)
    ]], { target.characterId, law.code, ident.characterId, note })

    Core:Log(src, 'police.charge', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { targetCharacterId = target.characterId, lawCode = law.code,
                    officerCharacterId = ident.characterId, note = note },
    })
    reply(src, true, ('Eintrag erstellt: %s (%s).'):format(law.code, law.title))
    reply(targetSrc, false, ('Strafregister-Eintrag: %s — %s'):format(law.code, law.title))
end, false)

-- /warrant <vorname> <nachname> <grund...>  (ab Sergeant)
RegisterCommand('warrant', function(src, args)
    if src == 0 then return end
    local ident = officer(src, 2)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst (ab Sergeant).') end
    if not args[1] or not args[2] or not args[3] then
        return reply(src, false, 'Nutzung: /warrant <vorname> <nachname> <grund>')
    end
    local char = findCharacterByName(args[1], args[2])
    if not char then return reply(src, false, 'Person nicht gefunden.') end

    local reason = table.concat(args, ' ', 3)
    local warrantId = Db.insert(
        'INSERT INTO warrants (character_id, reason, issued_by_character) VALUES (?, ?, ?)',
        { char.id, reason, ident.characterId })

    Core:Log(src, 'police.warrant', {
        target = { kind = 'character', id = tostring(char.id) },
        payload = { warrantId = warrantId, targetCharacterId = char.id,
                    reason = reason, issuedByCharacterId = ident.characterId, status = 'active' },
    })
    reply(src, true, ('Fahndung #%d ausgeschrieben: %s %s.'):format(warrantId, char.first_name, char.last_name))
end, false)

-- /warrantclose <warrantId> <executed|revoked>
RegisterCommand('warrantclose', function(src, args)
    if src == 0 then return end
    local ident = officer(src, 2)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst (ab Sergeant).') end
    local warrantId, status = tonumber(args[1]), args[2]
    if not warrantId or (status ~= 'executed' and status ~= 'revoked') then
        return reply(src, false, 'Nutzung: /warrantclose <id> <executed|revoked>')
    end
    local affected = Db.update([[
        UPDATE warrants SET status = ?, closed_at = NOW(3), closed_by_character = ?
        WHERE id = ? AND status = 'active'
    ]], { status, ident.characterId, warrantId })
    if affected == 0 then return reply(src, false, 'Fahndung nicht gefunden oder bereits geschlossen.') end

    Core:Log(src, 'police.warrant', {
        payload = { warrantId = warrantId, status = status, closedByCharacterId = ident.characterId },
    })
    reply(src, true, ('Fahndung #%d geschlossen (%s).'):format(warrantId, status))
end, false)

-- ---------------------------------------------------------------------------
-- Beweismittelkette (Chain of Custody)
-- ---------------------------------------------------------------------------

local function logCustody(src, ident, caseNumber, itemUuid, action, note)
    Db.insert([[
        INSERT INTO evidence_log (case_number, item_uuid, action, by_character, note)
        VALUES (?, ?, ?, ?, ?)
    ]], { caseNumber, itemUuid, action, ident.characterId, note or '' })
    Core:Log(src, 'evidence.custody', {
        target = { kind = 'item', id = itemUuid },
        payload = { caseNumber = caseNumber, itemUuid = itemUuid, action = action,
                    byCharacterId = ident.characterId, note = note },
    })
end

-- /newcase <titel...>
RegisterCommand('newcase', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local title = table.concat(args, ' ')
    if #title < 3 then return reply(src, false, 'Nutzung: /newcase <titel>') end

    local seq = (Db.scalar('SELECT COUNT(*) FROM evidence_cases') or 0) + 1
    local caseNumber = ('LSPD-%s-%04d'):format(os.date('%Y'), seq)
    Db.insert('INSERT INTO evidence_cases (case_number, title, created_by) VALUES (?, ?, ?)',
        { caseNumber, title, ident.characterId })

    Core:Log(src, 'evidence.case_open', {
        payload = { caseNumber = caseNumber, title = title, byCharacterId = ident.characterId },
    })
    reply(src, true, ('Fall angelegt: %s — %s'):format(caseNumber, title))
end, false)

-- /evstore <fallnummer> <item-uuid> [notiz...]
RegisterCommand('evstore', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local caseNumber, uuid = args[1], args[2]
    if not caseNumber or not uuid then return reply(src, false, 'Nutzung: /evstore <fallnummer> <item-uuid> [notiz]') end
    if not Db.scalar('SELECT 1 FROM evidence_cases WHERE case_number = ?', { caseNumber }) then
        return reply(src, false, 'Unbekannte Fallnummer.')
    end

    -- Item muss im eigenen Inventar sein (Beamter hat es sichergestellt)
    local owned = false
    for _, it in ipairs(Inv:GetContainer('character', ident.characterId) or {}) do
        if it.uuid == uuid then owned = true break end
    end
    if not owned then return reply(src, false, 'Dieses Item trägst du nicht bei dir.') end

    local ok, err = Inv:Move(uuid, { type = 'evidence', id = caseNumber }, { srcForLog = src })
    if not ok then return reply(src, false, 'Einlagerung fehlgeschlagen: ' .. tostring(err)) end

    logCustody(src, ident, caseNumber, uuid, 'stored', table.concat(args, ' ', 3))
    reply(src, true, ('Beweismittel eingelagert (%s).'):format(caseNumber))
end, false)

-- /evtake <fallnummer> <item-uuid> [notiz...]  (ab Sergeant; Entnahme wird protokolliert)
RegisterCommand('evtake', function(src, args)
    if src == 0 then return end
    local ident = officer(src, 2)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst (ab Sergeant).') end
    local caseNumber, uuid = args[1], args[2]
    if not caseNumber or not uuid then return reply(src, false, 'Nutzung: /evtake <fallnummer> <item-uuid> [notiz]') end

    local inCase = false
    for _, it in ipairs(Inv:GetContainer('evidence', caseNumber) or {}) do
        if it.uuid == uuid then inCase = true break end
    end
    if not inCase then return reply(src, false, 'Dieses Beweismittel liegt nicht in diesem Fall.') end

    local ok, err = Inv:Move(uuid, { type = 'character', id = ident.characterId }, { srcForLog = src })
    if not ok then return reply(src, false, 'Entnahme fehlgeschlagen: ' .. tostring(err)) end

    logCustody(src, ident, caseNumber, uuid, 'checked_out', table.concat(args, ' ', 3))
    reply(src, true, 'Beweismittel entnommen — Entnahme ist protokolliert.')
end, false)

-- /evlist <fallnummer>
RegisterCommand('evlist', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local caseNumber = args[1]
    if not caseNumber then return reply(src, false, 'Nutzung: /evlist <fallnummer>') end
    logMdtAccess(src, ident, 'evidence', nil, caseNumber)

    local items = Inv:GetContainer('evidence', caseNumber) or {}
    if #items == 0 then return reply(src, true, 'Keine Beweismittel in diesem Fall.') end
    for _, it in ipairs(items) do
        reply(src, true, ('%s · %s x%d%s · %s'):format(
            it.uuid:sub(1, 8), it.label, it.quantity,
            it.serial_number and (' · SN ' .. it.serial_number) or '', caseNumber))
    end
end, false)

-- ---------------------------------------------------------------------------
-- Cuff / Durchsuchung / Beschlagnahme / Forensik
-- ---------------------------------------------------------------------------

local cuffed = {}   -- cuffed[targetSrc] = true

RegisterCommand('cuff', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local targetSrc = tonumber(args[1])
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target then return reply(src, false, 'Spieler nicht gefunden.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 3.0 then
        return reply(src, false, 'Zu weit weg.')
    end

    cuffed[targetSrc] = not cuffed[targetSrc]
    TriggerClientEvent('hrp:police:cuffed', targetSrc, cuffed[targetSrc])
    Core:Log(src, 'police.cuff', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { targetCharacterId = target.characterId, cuffed = cuffed[targetSrc] == true,
                    officerCharacterId = ident.characterId },
    })
    reply(src, true, cuffed[targetSrc] and 'Handschellen angelegt.' or 'Handschellen abgenommen.')
end, false)

-- /searchplayer <id> <rechtsgrundlage...> — Durchsuchung MIT Begründungspflicht
RegisterCommand('searchplayer', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local targetSrc = tonumber(args[1])
    local basis = table.concat(args, ' ', 2)
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if #basis < 5 then return reply(src, false, 'Rechtsgrundlage angeben: /searchplayer <id> <grund>') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetSrc))) > 3.0 then
        return reply(src, false, 'Zu weit weg.')
    end

    Core:Log(src, 'police.search', {
        target = { kind = 'character', id = tostring(target.characterId) },
        payload = { targetCharacterId = target.characterId, legalBasis = basis,
                    officerCharacterId = ident.characterId },
    })
    local items = Inv:GetContainer('character', target.characterId) or {}
    if #items == 0 then return reply(src, true, 'Keine Gegenstände gefunden.') end
    for _, it in ipairs(items) do
        reply(src, true, ('%s · %s x%d%s'):format(it.uuid:sub(1, 8), it.label, it.quantity,
            it.serial_number and (' · SN ' .. it.serial_number) or ''))
    end
    reply(targetSrc, false, ('Du wirst durchsucht. Grund: %s'):format(basis))
end, false)

-- /confiscate <id> <item-uuid> <fallnummer> — direkt in die Beweismittelkette
RegisterCommand('confiscate', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local targetSrc, uuid, caseNumber = tonumber(args[1]), args[2], args[3]
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not uuid or not caseNumber then
        return reply(src, false, 'Nutzung: /confiscate <id> <item-uuid> <fallnummer>')
    end
    if not Db.scalar('SELECT 1 FROM evidence_cases WHERE case_number = ?', { caseNumber }) then
        return reply(src, false, 'Unbekannte Fallnummer (/newcase).')
    end

    local ok, err = Inv:Move(uuid, { type = 'evidence', id = caseNumber }, { srcForLog = src })
    if not ok then return reply(src, false, 'Beschlagnahme fehlgeschlagen: ' .. tostring(err)) end
    logCustody(src, ident, caseNumber, uuid, 'stored', 'Beschlagnahme bei Durchsuchung')
    reply(src, true, 'Beschlagnahmt und als Beweismittel eingelagert.')
    reply(targetSrc, false, 'Ein Gegenstand wurde beschlagnahmt.')
end, false)

-- /inspectitem <item-uuid> — Fingerabdruck-Auswertung (Spuren-Kit nötig)
RegisterCommand('inspectitem', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local uuid = args[1]
    if not uuid then return reply(src, false, 'Nutzung: /inspectitem <item-uuid>') end

    local hasKit = false
    for _, it in ipairs(Inv:GetContainer('character', ident.characterId) or {}) do
        if it.name == 'evidence_kit' then hasKit = true break end
    end
    if not hasKit then return reply(src, false, 'Du brauchst ein Spuren-Kit.') end

    local meta = Inv:GetInstanceMeta(uuid)
    if not meta then return reply(src, false, 'Item nicht gefunden.') end
    logMdtAccess(src, ident, 'forensics', nil, uuid)

    local prints = meta.metadata.prints or {}
    if #prints == 0 then return reply(src, true, 'Keine verwertbaren Abdrücke.') end
    for _, charId in ipairs(prints) do
        local person = Db.single('SELECT first_name, last_name FROM characters WHERE id = ?', { charId })
        reply(src, true, ('Abdruck: %s'):format(person
            and (person.first_name .. ' ' .. person.last_name) or ('Unbekannt (#' .. charId .. ')')))
    end
end, false)

AddEventHandler('playerDropped', function()
    cuffed[source] = nil
end)

-- /wanted — alle aktiven Fahndungen
RegisterCommand('wanted', function(src)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    logMdtAccess(src, ident, 'wanted_list', nil, '*')

    local rows = Db.query([[
        SELECT w.id, w.reason, c.first_name, c.last_name FROM warrants w
        JOIN characters c ON c.id = w.character_id
        WHERE w.status = 'active' ORDER BY w.created_at DESC LIMIT 20
    ]]) or {}
    if #rows == 0 then return reply(src, true, 'Keine aktiven Fahndungen.') end
    for _, w in ipairs(rows) do
        reply(src, false, ('FAHNDUNG #%d: %s %s — %s'):format(w.id, w.first_name, w.last_name, w.reason))
    end
end, false)

-- /serialcheck <seriennummer> — Waffenabfrage über das Seriennummern-System
RegisterCommand('serialcheck', function(src, args)
    if src == 0 then return end
    local ident = officer(src)
    if not ident then return reply(src, false, 'Nur Polizei im Dienst.') end
    local serial = args[1] and args[1]:upper()
    if not serial then return reply(src, false, 'Nutzung: /serialcheck <seriennummer>') end
    logMdtAccess(src, ident, 'weapon_serial', nil, serial)

    local row = Db.single([[
        SELECT i.uuid, i.shots_fired, i.created_at, d.label,
               l.container_type, l.container_id
        FROM item_instances i
        JOIN item_definitions d ON d.id = i.definition_id
        LEFT JOIN item_locations l ON l.instance_id = i.id
        WHERE i.serial_number = ?
    ]], { serial })
    if not row then return reply(src, false, 'Seriennummer nicht registriert.') end
    reply(src, true, ('%s · SN %s · registriert %s · Ort: %s'):format(
        row.label, serial, tostring(row.created_at):sub(1, 10),
        row.container_type == 'character' and 'in Personenbesitz' or (row.container_type or 'unbekannt')))
end, false)
