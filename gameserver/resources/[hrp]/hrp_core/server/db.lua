--[[
    Dünner DB-Layer über oxmysql. Ausschließlich Platzhalter-Queries
    (Prepared Statements) — niemals String-Konkatenation mit User-Input.
]]

Db = {}

--- SELECT mehrere Zeilen
function Db.query(sql, params)
    return MySQL.query.await(sql, params or {})
end

--- SELECT eine Zeile (oder nil)
function Db.single(sql, params)
    return MySQL.single.await(sql, params or {})
end

--- SELECT einzelner Wert
function Db.scalar(sql, params)
    return MySQL.scalar.await(sql, params or {})
end

--- INSERT, gibt insertId zurück
function Db.insert(sql, params)
    return MySQL.insert.await(sql, params or {})
end

--- UPDATE/DELETE, gibt affectedRows zurück
function Db.update(sql, params)
    return MySQL.update.await(sql, params or {})
end

--- Mehrere Statements atomar (oxmysql-Transaktion)
function Db.transaction(queries)
    return MySQL.transaction.await(queries)
end
