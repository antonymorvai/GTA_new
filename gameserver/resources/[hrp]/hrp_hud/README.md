# hrp_hud

Minimalistisches HUD (NUI, unten links): Gesundheit, Rüstung (nur wenn > 0),
Hunger, Durst, im Fahrzeug zusätzlich Tankanzeige und Tacho (km/h).
Werte < 20 % pulsieren.

Rein darstellend — Quellen: lokale Natives (HP/Rüstung/Speed), Server-Pushes
`hrp:medical:vitals` (Vitals-Tick + Abfrage nach Spawn) und
`hrp:vehicles:fuel` (10-s-Tick an den Fahrer).

DoD: 1 ✅ 2 (keine Mutationen) ✅ 3 (keine Balancing-Werte) ✅ 4 — ✅ 5 ✅
