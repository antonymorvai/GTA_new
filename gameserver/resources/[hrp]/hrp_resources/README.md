# hrp_resources

Dynamische Ressourcen: endliche, regenerierende Pools (Fischen, Bergbau, Holz,
Anbau). `/harvest` am Pool — Ertrag skaliert mit Skill-Level, jeder Abbau senkt
den Bestand (`resource.harvest`), leere Pools werfen nichts ab
(`resource.depleted`) → Overfarming zwingt zum Gebietswechsel. Regeneration
pro Tick; Director-Hook `Boom()` für Ressourcen-Booms.

Tuning: `resources.base_yield` (1) · `resources.xp_per_harvest` (15) ·
`resources.regen_tick_minutes` (10). Pools selbst sind DB-Daten
(`resource_pools`, `/hrp_resources_reload`).

DoD: 1 ✅ 2 ✅ 3 ✅ 4 ✅ 5 ✅ — Werkzeug-Verschleiß und Wildtier-Population
(Jagd-Simulation) folgen später.
