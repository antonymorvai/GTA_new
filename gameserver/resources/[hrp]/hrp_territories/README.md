# hrp_territories

Gang-Einfluss pro Stadtteil als **kontinuierlicher Wert** (0–100), kein
Capture-Timer: Aktivitäten erhöhen Einfluss (`AddInfluence`, z. B. pro
Drogen-Deal), Verfall pro Tick ohne Pflege (`territory.tick`). Auswirkung:
`GetSaleModifier(x, y, charId)` — dominante eigene Gang verkauft Illegales
teurer, in fremd dominiertem Gebiet gibt es Abschlag.

Admin-Bootstrap: `/setgang <id> <gang|none> [rank]` (UCP-Verwaltung folgt).
Tuning: `territories.decay_tick_minutes` (60) · `decay_per_tick` (2.0) ·
`influence_per_deal` (1.5) · `sale_bonus_max` (0.25) · `sale_malus_max` (0.30).

DoD: 1 ✅ 2 ✅ 3 ✅ 4 ✅ 5 ✅ — NPC-Verhalten, Graffiti/Schutzgeld als
Einfluss-Quellen und MDT-Streifen-Empfehlungen folgen später.
