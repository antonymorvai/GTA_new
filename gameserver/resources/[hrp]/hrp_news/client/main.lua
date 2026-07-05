-- /artikel Schlagzeile | Text — publiziert (Journalist); /zeitung — Schlagzeilen

RegisterCommand('artikel', function(_, args)
    local raw = table.concat(args, ' ')
    local headline, body = raw:match('^(.-)%s*|%s*(.+)$')
    if not headline or not body then
        TriggerEvent('chat:addMessage', { args = { '^1WEAZEL', 'Nutzung: /artikel Schlagzeile | Artikeltext' } })
        return
    end
    TriggerServerEvent('hrp:news:publish', headline, body)
end, false)

RegisterCommand('zeitung', function() TriggerServerEvent('hrp:news:read') end, false)
