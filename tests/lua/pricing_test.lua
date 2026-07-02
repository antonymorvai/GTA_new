-- Unit-Tests für die Wirtschafts-Preisformel (DoD Regel 1: getestet).
-- Ausführung: scripts/test-lua.sh (Standard-Lua, keine FiveM-Natives nötig).

dofile('gameserver/resources/[hrp]/hrp_economy/shared/pricing.lua')

local failures = 0
local function check(name, condition, detail)
    if condition then
        print(('  PASS  %s'):format(name))
    else
        failures = failures + 1
        print(('  FAIL  %s%s'):format(name, detail and (' — ' .. detail) or ''))
    end
end

local defaults = {
    basePrice = 1000, sensitivity = 0.6, smoothing = 0.25,
    minFactor = 0.5, maxFactor = 2.0, targetStock = 100,
}
local function tick(overrides)
    local p = {}
    for k, v in pairs(defaults) do p[k] = v end
    for k, v in pairs(overrides) do p[k] = v end
    return HRPPricing.Tick(p)
end

print('HRPPricing.Tick')

-- Gleichgewicht: Bestand = Ziel -> Preis bleibt beim Basispreis
check('Gleichgewicht hält den Preis', tick({ currentPrice = 1000, stock = 100 }) == 1000)

-- Knappheit: Bestand unter Ziel -> Preis steigt
local scarce = tick({ currentPrice = 1000, stock = 20 })
check('Knappheit erhöht den Preis', scarce > 1000, 'ist ' .. scarce)

-- Überproduktion: Bestand über Ziel -> Preis fällt
local glut = tick({ currentPrice = 1000, stock = 300 })
check('Überangebot senkt den Preis', glut < 1000, 'ist ' .. glut)

-- Klemme: extreme Knappheit überschreitet nie base*maxFactor
local price = 1000
for _ = 1, 100 do
    price = tick({ currentPrice = price, stock = 0 })
end
check('Obergrenze base*maxFactor greift', price <= 2000, 'ist ' .. price)
check('Konvergenz nach oben erreicht Grenzbereich', price >= 1550, 'ist ' .. price)

-- Klemme: extremes Überangebot unterschreitet nie base*minFactor
price = 1000
for _ = 1, 100 do
    price = tick({ currentPrice = price, stock = 10000 })
end
check('Untergrenze base*minFactor greift', price >= 500, 'ist ' .. price)

-- Glättung: ein einzelner Tick springt nicht direkt zum Zielpreis
local oneStep = tick({ currentPrice = 1000, stock = 0 })  -- Zielpreis wäre 1600
check('Glättung dämpft Sprünge', oneStep > 1000 and oneStep < 1600, 'ist ' .. oneStep)

-- Preis nie unter 1 Cent
check('Preis fällt nie unter 1', tick({ basePrice = 1, currentPrice = 1, stock = 10000, minFactor = 0 }) >= 1)

print('HRPPricing.SellToShopPrice')
check('Ankauf liegt unter Verkauf', HRPPricing.SellToShopPrice(1000, 0.3) == 700)
check('Ankauf nie unter 1', HRPPricing.SellToShopPrice(1, 0.99) >= 1)

print('HRPPricing.Restock')
check('Restock füllt Richtung Ziel', HRPPricing.Restock(50, 10, 100) == 60)
check('Restock überschreitet Ziel nicht', HRPPricing.Restock(95, 10, 100) == 100)
check('Voller Bestand bleibt', HRPPricing.Restock(100, 10, 100) == 100)

if failures > 0 then
    print(('%d Test(s) fehlgeschlagen.'):format(failures))
    os.exit(1)
end
print('Alle Lua-Tests bestanden.')
