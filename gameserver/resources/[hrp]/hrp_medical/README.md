# hrp_medical

Verletzungssystem & Rettungsdienst-Basis:
- **Kampf-Logging:** `weaponDamageEvent` server-seitig → `combat.damage` mit
  Trefferzone, Waffe, Distanz; probabilistische Verletzungen pro Zone
  (`character_injuries`, Schwere 1–3, Blutung mit HP-Verlust bis Verband).
- **Bewusstlosigkeit statt Respawn:** `combat.down` mit Verursacher; Ragdoll
  vor Ort, EMS-`/revive` oder nach Bleed-out `/respawn` in die Klinik
  (Verletzungen gelten dann als grundversorgt, Krankenakten-Eintrag).
- **Krankenakten** (`medical_records`), `/diagnose` (geloggter Aktenzugriff),
  `/treat`.
- **Vitals:** Hunger/Durst sinken pro Tick, bei 0 Schaden; `/use <uuid>`
  konsumiert Items (Wasser/Brot/Verband) über das Inventar-Event `hrp:items:used`.

## Befehle
EMS (im Dienst): `/revive <id>` · `/diagnose <id>` · `/treat <id> [notiz]`
Alle: `/respawn` (nach Bleed-out) · `/vitals` · `/use <item-uuid>`

## Live-Tuning
`medical.bleedout_seconds` (300) · `medical.injury_chance_base` (0.35) ·
`medical.injury_damage_divisor` (200) · `medical.vitals_tick_minutes` (5) ·
`medical.hunger_per_tick` (3) · `medical.thirst_per_tick` (4)

## Definition of Done (Phase-3-Scope)
1. Lauffähig ✅ 2. combat./medical./character.state_change ✅ 3. Tuning ✅
4. Kill-Akte-Datenbasis (combat.down + position_samples) ✅ 5. Doku ✅ —
Frakturen-Debuffs, OPs, Blutkonserven, Psychologie und Sucht folgen später.
