# hrp_vehicles

Fahrzeug-Basis: Kauf beim Händler (Bankzahlung, korreliert mit `vehicle.buy`),
Garagen (aus-/einparken, Persistenz von Tank/Kilometern/Zustand), Schlüssel-
verwaltung mit geloggten Übergaben, server-seitig gemessener Kraftstoff-
verbrauch + Kilometerstand (Motor stirbt bei leerem Tank), Tanken an
Tankstellen, Ein-/Aussteige-Logging.

## Befehle
`/buycar <modell>` (am Händler) · `/garage <kennzeichen>` · `/park` ·
`/givekey <spielerId> <kennzeichen>` · `/refuel` · `/myvehicles`

## Live-Tuning
`vehicles.fuel_price_per_liter` (180 Cent — echte Tankstellen-Bestände
ersetzen den Fixpreis in Phase 4 mit den Lieferketten).

## Events
`vehicle.buy/spawn/store/enter/exit/key_grant/refuel` (Katalog §vehicle).

## Definition of Done (Phase-2-Scope)
1. Lauffähig ✅ 2. Alle Mutationen geloggt ✅ 3. Tuning ✅ 4. ACP-Datenbasis ✅
5. Doku ✅ — Verschleiß, HU/TÜV, Versicherung, Kennzeichen-Features und
Gebrauchtmarkt folgen Phase 3+ auf diesem Schema.
