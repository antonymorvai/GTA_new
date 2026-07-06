--[[
    Diminishing Returns (Design-Verfassung §0: „RP ist die Belohnung").

    Jede aktive Einkommensquelle hat eine TAGES-SÄTTIGUNG: die ersten Einnahmen
    zählen voll, danach degressiv bis zum Boden. Der 20-h-Grinder verdient ab
    der Sättigung kaum mehr als der 2-h-Abendspieler — Geld-Maximierung lohnt
    nicht, Geschichten schon.

    Stufen (Schwelle T = Tuning je Quelle überschreibbar):
      bis 1×T: 100 % · bis 2×T: 70 % · bis 3×T: 40 % · darüber: Boden (25 %)

    In-Memory pro Tag (Restart resettet — bewusst großzügig zugunsten der
    Spieler; die vollen Beträge stehen ohnehin im Log-Store).
]]

HRP.Earnings = {}

-- earned[characterId] = { day = 'YYYY-MM-DD', bySource = { [source] = cents } }
local earned = {}

local function bucket(characterId)
    local today = os.date('%Y-%m-%d')
    local entry = earned[characterId]
    if not entry or entry.day ~= today then
        entry = { day = today, bySource = {} }
        earned[characterId] = entry
    end
    return entry
end

--- Faktor für die nächste Auszahlung dieser Quelle (0.25 .. 1.0).
function HRP.Earnings.Factor(characterId, source)
    local threshold = HRP.Tuning.Get('earnings.threshold_' .. source,
        HRP.Tuning.Get('earnings.threshold_default', 100000))   -- 1.000 $ voll
    local floor = HRP.Tuning.Get('earnings.floor', 0.25)
    local sum = bucket(characterId).bySource[source] or 0

    if sum < threshold then return 1.0 end
    if sum < threshold * 2 then return 0.7 end
    if sum < threshold * 3 then return 0.4 end
    return floor
end

--- Wendet die Sättigung an: gibt (angepasster Betrag, Faktor) zurück und
--- verbucht den ANGEPASSTEN Betrag aufs Tageskonto der Quelle.
function HRP.Earnings.Apply(characterId, source, amount)
    local factor = HRP.Earnings.Factor(characterId, source)
    local adjusted = math.max(1, math.floor(amount * factor))
    local entry = bucket(characterId)
    entry.bySource[source] = (entry.bySource[source] or 0) + adjusted
    return adjusted, factor
end

exports('EarningsApply', function(...) return HRP.Earnings.Apply(...) end)
exports('EarningsFactor', function(...) return HRP.Earnings.Factor(...) end)
