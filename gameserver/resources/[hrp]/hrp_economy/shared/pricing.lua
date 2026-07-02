--[[
    Preisformel der dynamischen Wirtschaft — PURE Funktionen (keine Natives,
    keine DB), damit sie mit Standard-Lua testbar sind (scripts/test-lua.sh).

    Modell:
      Knappheit  s = (targetStock - stock) / targetStock   (-∞ .. 1]
      Zielpreis  p* = basePrice * (1 + sensitivity * s)
      Glättung   p' = p + smoothing * (p* - p)             (kein Preis-Zickzack)
      Klemme     p' ∈ [basePrice * minFactor, basePrice * maxFactor]

    Überproduktion (stock >> target) drückt s < 0 -> Preisverfall.
    Knappheit (stock << target)      hebt  s -> Preisanstieg.
    Alle Parameter kommen zur Laufzeit aus dem Tuning (Kernprinzip B).
]]

HRPPricing = {}

--- Einen Preis-Tick berechnen. params:
---   basePrice, currentPrice, stock, targetStock,
---   sensitivity (z. B. 0.6), smoothing (0..1, z. B. 0.25),
---   minFactor (z. B. 0.5), maxFactor (z. B. 2.0)
--- Rückgabe: neuer Preis in Cent (Integer, >= 1)
function HRPPricing.Tick(params)
    local target = math.max(params.targetStock, 1)
    local scarcity = (target - params.stock) / target
    local desired = params.basePrice * (1 + params.sensitivity * scarcity)
    local smoothed = params.currentPrice + params.smoothing * (desired - params.currentPrice)

    local minPrice = params.basePrice * params.minFactor
    local maxPrice = params.basePrice * params.maxFactor
    local clamped = math.min(math.max(smoothed, minPrice), maxPrice)

    return math.max(1, math.floor(clamped + 0.5))
end

--- Ankaufspreis des Shops (Spieler verkauft AN den Shop): Abschlag auf den
--- aktuellen Verkaufspreis, damit Kauf->Verkauf-Schleifen nie profitabel sind.
function HRPPricing.SellToShopPrice(currentPrice, sellMargin)
    return math.max(1, math.floor(currentPrice * (1 - sellMargin) + 0.5))
end

--- Bestands-Regeneration pro Tick (Lieferketten ersetzen das in Phase 4).
function HRPPricing.Restock(stock, restockRate, targetStock)
    if stock >= targetStock then return stock end
    return math.min(targetStock, stock + restockRate)
end

return HRPPricing
