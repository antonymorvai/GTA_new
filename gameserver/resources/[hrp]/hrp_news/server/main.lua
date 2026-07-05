--[[
    hrp_news – Zeitung: Journalisten (im Dienst) publizieren Artikel
    (/artikel Schlagzeile | Text), Server-weite Eilmeldung, Archiv über
    /zeitung in-game und die öffentliche Web-Seite. comms.article geloggt.
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.insert(sql, p) return MySQL.insert.await(sql, p or {}) end

local Core = exports.hrp_core
local Jobs = exports.hrp_jobs

local function reply(src, ok, msg)
    TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2WEAZEL' or '^1WEAZEL', msg } })
end

Core:RegisterSecureEvent('hrp:news:publish', {
    rate = 0.1, burst = 1,
    schema = { { type = 'string', maxLen = 200 }, { type = 'string', maxLen = 4000 } },
}, function(src, headline, body)
    local ident = Core:GetPlayerIdentity(src)
    local job = Jobs:GetJob(ident.characterId)
    if not job or job.name ~= 'journalist' or job.on_duty ~= 1 then
        return reply(src, false, 'Nur Journalisten im Dienst publizieren.')
    end
    if #headline < 5 or #body < 30 then
        return reply(src, false, 'Schlagzeile min. 5, Text min. 30 Zeichen.')
    end

    local articleId = Db.insert(
        'INSERT INTO news_articles (author_id, headline, body) VALUES (?, ?, ?)',
        { ident.characterId, headline, body })

    Core:Log(src, 'comms.article', {
        target = { kind = 'article', id = tostring(articleId) },
        payload = { articleId = articleId, headline = headline, bodyLength = #body },
    })

    TriggerClientEvent('chat:addMessage', -1, {
        args = { '^6📰 WEAZEL NEWS', ('EILMELDUNG: %s — mehr unter /zeitung'):format(headline) },
    })
    reply(src, true, ('Artikel #%d publiziert.'):format(articleId))
end)

Core:RegisterSecureEvent('hrp:news:read', { rate = 0.5, burst = 2 }, function(src)
    local rows = Db.query([[
        SELECT a.headline, a.published_at, c.first_name, c.last_name
        FROM news_articles a JOIN characters c ON c.id = a.author_id
        ORDER BY a.published_at DESC LIMIT 8
    ]]) or {}
    if #rows == 0 then return reply(src, true, 'Noch keine Artikel.') end
    for i = #rows, 1, -1 do
        reply(src, true, ('%s — von %s %s'):format(rows[i].headline, rows[i].first_name, rows[i].last_name))
    end
end)
