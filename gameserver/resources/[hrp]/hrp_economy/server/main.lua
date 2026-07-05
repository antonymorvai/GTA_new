--[[
    hrp_economy – Shops mit dynamischen Preisen.

    - Kauf/Verkauf laufen server-autoritativ über Geld-API + Inventar-API,
      verknüpft per correlationId (eine Transaktion = ein Korrelations-Strang).
    - Jeder Kauf senkt den Bestand (Preis steigt beim nächsten Tick),
      jeder Verkauf erhöht ihn (Preis fällt) — Angebot & Nachfrage.
    - Preis-Tick: periodisch, Parameter live aus dem Tuning, jede Preisänderung
      als economy.price_tick-Event (Datenbasis für Börsenticker & ACP).
]]

local Db = {}
function Db.query(sql, p) return MySQL.query.await(sql, p or {}) end
function Db.single(sql, p) return MySQL.single.await(sql, p or {}) end
function Db.update(sql, p) return MySQL.update.await(sql, p or {}) end

local Core = exports.hrp_core
local Inv = exports.hrp_inventory
local Logger = exports.hrp_logger

-- shops[shopId] = {row, items = {[defName] = shopItemRow}}
local shops = {}

local function loadShops()
    shops = {}
    for _, s in ipairs(Db.query('SELECT * FROM shops') or {}) do
        shops[s.id] = { row = s, items = {} }
    end
    local items = Db.query([[
        SELECT si.*, d.name AS def_name, d.label AS def_label, d.max_stack
        FROM shop_items si JOIN item_definitions d ON d.id = si.definition_id
    ]]) or {}
    for _, it in ipairs(items) do
        if shops[it.shop_id] then
            shops[it.shop_id].items[it.def_name] = it
        end
    end
    print(('[hrp_economy] %d Shops geladen.'):format(#(Db.query('SELECT id FROM shops') or {})))
end

MySQL.ready(loadShops)
RegisterCommand('hrp_economy_reload', function(src) if src == 0 then loadShops() end end, true)

local function tuning()
    return {
        sensitivity = Core:TuningGet('economy.price_sensitivity', 0.6),
        smoothing   = Core:TuningGet('economy.price_smoothing', 0.25),
        minFactor   = Core:TuningGet('economy.price_min_factor', 0.5),
        maxFactor   = Core:TuningGet('economy.price_max_factor', 2.0),
        sellMargin  = Core:TuningGet('economy.sell_margin', 0.3),
        tickMinutes = Core:TuningGet('economy.price_tick_minutes', 15),
        maxPerPurchase = Core:TuningGet('economy.max_qty_per_purchase', 10),
    }
end

local function findShopNear(src, radius)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for id, shop in pairs(shops) do
        local d = #(pos - vector3(shop.row.pos_x, shop.row.pos_y, shop.row.pos_z))
        if d <= (radius or 5.0) then return id, shop end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Kauf / Verkauf (abgesicherte Client-Events)
-- ---------------------------------------------------------------------------

Core:RegisterSecureEvent('hrp:economy:buy', {
    rate = 2, burst = 4,
    schema = {
        { type = 'string', maxLen = 64, pattern = '^[%w_]+$' },   -- itemName
        { type = 'number', integer = true, min = 1, max = 100 },  -- quantity
    },
}, function(src, itemName, quantity)
    local t = tuning()
    if quantity > t.maxPerPurchase then quantity = t.maxPerPurchase end

    local shopId, shop = findShopNear(src)
    local item = shop and shop.items[itemName]
    local function reply(ok, msg)
        TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2SHOP' or '^1SHOP', msg } })
    end
    if not item or item.can_buy ~= 1 then return reply(false, 'Dieser Artikel ist hier nicht erhältlich.') end
    if item.stock < quantity then return reply(false, ('Nur noch %d Stück auf Lager.'):format(item.stock)) end

    local ident = Core:GetPlayerIdentity(src)
    local total = item.current_price * quantity
    local correlationId = Logger:NewCorrelationId()

    -- 1) Geld abbuchen (Senke: Systemkauf)
    local paid, err = Core:MoneyDestroy(ident.characterId, 'cash', total, 'system.buy', { correlationId = correlationId })
    if not paid then
        return reply(false, err == 'insufficient_funds' and 'Nicht genug Bargeld.' or 'Zahlung fehlgeschlagen.')
    end

    -- 2) Item erzeugen (Quelle: Shop)
    local uuid, itemErr = Inv:Create(itemName, quantity, 'shop.buy',
        { type = 'character', id = ident.characterId },
        { createdBy = ident.characterId, correlationId = correlationId, srcForLog = src })
    if not uuid then
        -- Kompensation: Geld zurück (gleiche Korrelation -> im ACP als ein Vorgang lesbar)
        Core:MoneyCreate(ident.characterId, 'cash', total, 'system.sell', { correlationId = correlationId })
        return reply(false, itemErr == 'too_heavy' and 'Du kannst nicht mehr tragen.' or 'Kauf fehlgeschlagen.')
    end

    -- 3) Bestand senken (Nachfrage-Signal für den nächsten Preis-Tick)
    item.stock = item.stock - quantity
    Db.update('UPDATE shop_items SET stock = ? WHERE id = ?', { item.stock, item.id })

    reply(true, ('%dx %s gekauft für %s $.'):format(quantity, item.def_label, string.format('%.2f', total / 100)))
end)

Core:RegisterSecureEvent('hrp:economy:sell', {
    rate = 2, burst = 4,
    schema = { { type = 'string', maxLen = 36, pattern = '^[%x%-]+$' } },  -- item uuid
}, function(src, uuid)
    local t = tuning()
    local shopId, shop = findShopNear(src)
    local function reply(ok, msg)
        TriggerClientEvent('chat:addMessage', src, { args = { ok and '^2SHOP' or '^1SHOP', msg } })
    end
    if not shop then return reply(false, 'Kein Shop in der Nähe.') end

    local ident = Core:GetPlayerIdentity(src)

    -- Besitz + Definition prüfen
    local owned = Inv:GetContainer('character', ident.characterId) or {}
    local instance
    for _, it in ipairs(owned) do
        if it.uuid == uuid then instance = it break end
    end
    if not instance then return reply(false, 'Item nicht in deinem Inventar.') end

    local item = shop.items[instance.name]
    if not item or item.can_sell ~= 1 then return reply(false, 'Dieser Shop kauft das nicht an.') end

    local unitPrice = HRPPricing.SellToShopPrice(item.current_price, t.sellMargin)
    local total = unitPrice * instance.quantity
    local correlationId = Logger:NewCorrelationId()

    -- 1) Item vernichten (Senke: Verkauf an System)
    local destroyed = Inv:Destroy(uuid, 'shop.sell', { correlationId = correlationId, srcForLog = src })
    if not destroyed then return reply(false, 'Verkauf fehlgeschlagen.') end

    -- 2) Geld erzeugen (Quelle: Systemverkauf)
    Core:MoneyCreate(ident.characterId, 'cash', total, 'system.sell', { correlationId = correlationId })

    -- 3) Bestand erhöhen (Angebots-Signal)
    item.stock = item.stock + instance.quantity
    Db.update('UPDATE shop_items SET stock = ? WHERE id = ?', { item.stock, item.id })

    reply(true, ('%dx %s verkauft für %s $.'):format(instance.quantity, instance.label, string.format('%.2f', total / 100)))
end)

-- Preisliste des nächsten Shops (für Client-UI / Tests)
Core:RegisterSecureEvent('hrp:economy:requestPrices', { rate = 1, burst = 2 }, function(src)
    local shopId, shop = findShopNear(src, 10.0)
    if not shop then return end
    local list = {}
    for defName, it in pairs(shop.items) do
        list[#list + 1] = {
            name = defName, label = it.def_label, price = it.current_price,
            stock = it.stock, canBuy = it.can_buy == 1, canSell = it.can_sell == 1,
        }
    end
    TriggerClientEvent('hrp:economy:prices', src, shop.row.label, list)
end)

-- ---------------------------------------------------------------------------
-- Preis-Tick (Angebot & Nachfrage) + Restock
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local t = tuning()
        Wait(math.max(1, t.tickMinutes) * 60000)

        local changes = {}
        for shopId, shop in pairs(shops) do
            for defName, item in pairs(shop.items) do
                item.stock = HRPPricing.Restock(item.stock, item.restock_rate, item.target_stock)
                local newPrice = HRPPricing.Tick({
                    basePrice = item.base_price,
                    currentPrice = item.current_price,
                    stock = item.stock,
                    targetStock = item.target_stock,
                    sensitivity = t.sensitivity,
                    smoothing = t.smoothing,
                    minFactor = t.minFactor,
                    maxFactor = t.maxFactor,
                })
                if newPrice ~= item.current_price then
                    changes[#changes + 1] = {
                        shop = shop.row.name, region = shop.row.region, item = defName,
                        before = item.current_price, after = newPrice, stock = item.stock,
                    }
                    item.current_price = newPrice
                end
                Db.update('UPDATE shop_items SET current_price = ?, stock = ? WHERE id = ?',
                    { item.current_price, item.stock, item.id })
            end
        end

        if #changes > 0 then
            Logger:Log('economy.price_tick', { payload = { changes = changes } })
        end
    end
end)
