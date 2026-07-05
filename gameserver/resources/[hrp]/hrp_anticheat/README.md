# hrp_anticheat

Server-seitige Plausibilitätsprüfungen mit Strike-System. Philosophie:
**erkennen und loggen zuerst** (`security.anticheat`-Events → ACP/Anomalie-
Analyse), automatischer Kick nur, wenn per Tuning aktiviert — der eigentliche
Schutz ist die server-autoritative Architektur des Frameworks.

## Checks
| Check | Erkennung |
|---|---|
| `teleport` | > `anticheat.max_distance_per_5s` (400 m) Bewegung ohne angemeldeten Teleport |
| `health_range` / `armor_range` | Werte außerhalb der Engine-Grenzen (Godmode-Indikator) |
| `blacklisted_entity` | `entityCreating` mit Militär-/Blacklist-Modell → abgebrochen |
| `explosion` | Jedes `explosionEvent` geloggt; Unterdrückung via `anticheat.cancel_explosions` |

## AllowTeleport-Export
Legitime Teleports (Garage, Immobilie, Haft, Klinik, Admin-`/goto`) melden sich
mit `exports.hrp_anticheat:AllowTeleport(src, ms)` an — sonst wäre jedes
Framework-Feature ein False Positive.

## Tuning
`anticheat.kick_strikes` (0 = nie kicken, nur loggen) ·
`anticheat.max_distance_per_5s` (400.0) · `anticheat.cancel_explosions` (false)

DoD: 1 ✅ 2 ✅ (alle Detections als Katalog-Events) 3 ✅ 4 ✅ (Log-Explorer:
`type=security.anticheat`) 5 ✅
