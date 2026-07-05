--[[
    hrp_companies – Firmen: Handelsregister, Mitglieder mit Rängen,
    Firmenkonto (alle Bewegungen über die Core-Geld-API, target 'company'),
    automatischer Lohnlauf aus Firmenmitteln.

    Ränge: 0 Mitarbeiter · 1 Leitung (darf einstellen/auszahlen) · 2 Inhaber.
    Buchhaltung/Kassenbuch im UCP (Phase 5) liest die money.*-Events;
    Betriebsprüfung & Insolvenz folgen auf dieser Datenbasis.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.scalar(sql, p) return MySQL.scalar.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Logger = exports.hrp_logger

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2FIRMA' or '^1FIRMA', msg } })
end

local function membership(characterId)
    return Db.single([[
        SELECT cm.company_id, cm.rank, cm.salary, c.name, c.label
        FROM company_members cm
        JOIN companies c ON c.id = cm.company_id AND c.dissolved_at IS NULL
        WHERE cm.character_id = ?
    ]], { characterId })
end

-- Gründung: Handelsregister-Eintrag (Admin/Verwaltung; UCP-Workflow folgt)
RegisterCommand('company_register', function(src, args)
    if src ~= 0 and not Core:HasPermission(src, 'game.admin.job_set') then return end
    local ownerSrc, name = tonumber(args[1]), args[2]
    local label = table.concat(args, ' ', 3)
    local owner = ownerSrc and Core:GetPlayerIdentity(ownerSrc)
    if not owner or not owner.characterId or not name or label == '' then
        if src == 0 then print('Usage: company_register <ownerServerId> <kuerzel> <firmenname...>') end
        return
    end
    if Db.scalar('SELECT 1 FROM companies WHERE name = ?', { name }) then
        if src == 0 then print('Kürzel bereits vergeben.') end
        return
    end

    local companyId = Db.insert('INSERT INTO companies (name, label, owner_id) VALUES (?, ?, ?)',
        { name, label, owner.characterId })
    Db.insert('INSERT INTO company_funds (company_id) VALUES (?)', { companyId })
    Db.insert('INSERT INTO company_members (company_id, character_id, rank) VALUES (?, ?, 2)',
        { companyId, owner.characterId })

    Core:Log(src ~= 0 and src or nil, 'company.create', {
        target = { kind = 'company', id = tostring(companyId) },
        payload = { companyId = companyId, name = name, label = label,
                    ownerCharacterId = owner.characterId },
    })
    local msg = ('Firma registriert: %s (%s), Inhaber Charakter %d'):format(label, name, owner.characterId)
    if src == 0 then print(msg) else reply(src, true, msg) end
    reply(ownerSrc, true, ('Deine Firma wurde registriert: %s'):format(label))
end, true)

-- /hire <serverId> <lohnEuro>  (Leitung+)
RegisterCommand('hire', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local my = membership(ident.characterId)
    if not my or my.rank < 1 then return reply(src, false, 'Du hast keine Einstellungsbefugnis.') end

    local targetSrc, salaryEuro = tonumber(args[1]), tonumber(args[2]) or 0
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    if membership(target.characterId) then return reply(src, false, 'Diese Person ist bereits angestellt.') end

    local salary = math.max(0, math.floor(salaryEuro * 100))
    Db.insert('INSERT INTO company_members (company_id, character_id, rank, salary) VALUES (?, ?, 0, ?)',
        { my.company_id, target.characterId, salary })

    Core:Log(src, 'company.hire', {
        target = { kind = 'company', id = tostring(my.company_id) },
        payload = { companyId = my.company_id, characterId = target.characterId,
                    salary = salary, byCharacterId = ident.characterId },
    })
    reply(src, true, 'Mitarbeiter eingestellt.')
    reply(targetSrc, true, ('Du wurdest eingestellt: %s (Lohn %s $/Lohnlauf).'):format(my.label, string.format('%.2f', salary / 100)))
end, false)

-- /fire <serverId>  (Leitung+)
RegisterCommand('fire', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    if not ident or not ident.characterId then return end
    local my = membership(ident.characterId)
    if not my or my.rank < 1 then return reply(src, false, 'Du hast keine Befugnis.') end

    local targetSrc = tonumber(args[1])
    local target = targetSrc and Core:GetPlayerIdentity(targetSrc)
    if not target or not target.characterId then return reply(src, false, 'Spieler nicht gefunden.') end
    local their = membership(target.characterId)
    if not their or their.company_id ~= my.company_id then return reply(src, false, 'Nicht in deiner Firma.') end
    if their.rank >= my.rank then return reply(src, false, 'Du kannst keine Gleich-/Höhergestellten entlassen.') end

    Db.update('DELETE FROM company_members WHERE company_id = ? AND character_id = ?',
        { my.company_id, target.characterId })
    Core:Log(src, 'company.fire', {
        target = { kind = 'company', id = tostring(my.company_id) },
        payload = { companyId = my.company_id, characterId = target.characterId,
                    byCharacterId = ident.characterId },
    })
    reply(src, true, 'Mitarbeiter entlassen.')
    reply(targetSrc, false, ('Du wurdest entlassen: %s'):format(my.label))
end, false)

-- /companydeposit <euro> · /companywithdraw <euro> (Leitung+)
RegisterCommand('companydeposit', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    local my = ident and ident.characterId and membership(ident.characterId)
    if not my then return reply(src, false, 'Du bist in keiner Firma.') end
    local amount = math.floor((tonumber(args[1]) or 0) * 100)
    if amount < 1 then return reply(src, false, 'Nutzung: /companydeposit <betrag>') end

    local ok, err = Core:MoneyCompanyTransfer(ident.characterId, my.company_id, 'bank',
        amount, 'to_company', 'company.deposit')
    reply(src, ok, ok and 'Einzahlung aufs Firmenkonto verbucht.'
        or (err == 'insufficient_funds' and 'Kontostand zu niedrig.' or 'Fehlgeschlagen.'))
end, false)

RegisterCommand('companywithdraw', function(src, args)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    local my = ident and ident.characterId and membership(ident.characterId)
    if not my or my.rank < 1 then return reply(src, false, 'Nur die Firmenleitung.') end
    local amount = math.floor((tonumber(args[1]) or 0) * 100)
    if amount < 1 then return reply(src, false, 'Nutzung: /companywithdraw <betrag>') end

    local ok, err = Core:MoneyCompanyTransfer(ident.characterId, my.company_id, 'bank',
        amount, 'to_character', 'company.withdraw')
    reply(src, ok, ok and 'Auszahlung verbucht.'
        or (err == 'insufficient_company_funds' and 'Firmenkonto gedeckt? Nein.' or 'Fehlgeschlagen.'))
end, false)

RegisterCommand('companybalance', function(src)
    if src == 0 then return end
    local ident = Core:GetPlayerIdentity(src)
    local my = ident and ident.characterId and membership(ident.characterId)
    if not my then return reply(src, false, 'Du bist in keiner Firma.') end
    local balance = Core:MoneyCompanyGetBalance(my.company_id) or 0
    reply(src, true, ('%s · Firmenkonto: %s $'):format(my.label, string.format('%.2f', balance / 100)))
end, false)

-- Firmen-Lohnlauf: zahlt Mitarbeitern ihr Gehalt AUS FIRMENMITTELN
-- (keine Deckung -> keine Zahlung + company.payroll_failed)
CreateThread(function()
    while true do
        local minutes = Core:TuningGet('companies.payroll_interval_minutes', 60)
        Wait(math.max(5, minutes) * 60000)

        for _, srcStr in ipairs(GetPlayers()) do
            local src = tonumber(srcStr)
            local ident = Core:GetPlayerIdentity(src)
            if ident and ident.characterId then
                local my = membership(ident.characterId)
                if my and (my.salary or 0) > 0 then
                    local correlationId = Logger:NewCorrelationId()
                    local ok = Core:MoneyCompanyTransfer(ident.characterId, my.company_id, 'bank',
                        my.salary, 'to_character', 'company.salary', { correlationId = correlationId })
                    if ok then
                        reply(src, true, ('Lohn von %s: %s $'):format(my.label, string.format('%.2f', my.salary / 100)))
                    else
                        Logger:Log('company.payroll_failed', {
                            target = { kind = 'company', id = tostring(my.company_id) },
                            payload = { companyId = my.company_id, characterId = ident.characterId,
                                        salary = my.salary, error = 'insufficient_company_funds' },
                        })
                    end
                end
            end
        end
    end
end)
