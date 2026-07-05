# hrp_properties

Immobilien: Kauf vom Staat (`/buyhouse`, Bankzahlung, `property.buy`
money-korreliert), Schlüssel/Mitbewohner (`/givehousekey`), Betreten über ein
gemeinsames Shell-Interior mit **Routing-Bucket = Objekt-ID** (Bewohner
verschiedener Wohnungen sehen sich nie). Jeder Zutrittsversuch wird MIT
Berechtigungsergebnis geloggt (`door.access`).

**Dynamische Preise:** Käufe heben die Preise der Region (Nachfrage), freie
Objekte laufen per Tick Richtung Basispreis zurück. Der Lage-Score aus echten
Kriminalitäts-Log-Daten fließt in Phase 5 über das Backend ein.

Tuning: `properties.demand_price_bump` (0.03) · `price_reversion` (0.02) ·
`price_tick_minutes` (60).

DoD: 1 ✅ 2 ✅ 3 ✅ 4 ✅ 5 ✅ — Möbel-Platzierung, Einbruch/Alarmanlagen,
Miete und Zwangsversteigerung folgen später.
