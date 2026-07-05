# hrp_justice

Justiz: **versioniertes Gesetzbuch** (Daten, nicht Konstanten — `/lawset`
erhöht die Version, schreibt einen `law_history`-Snapshot und ein
`law.change`-Event; der Gesetzgebungs-Workflow der Regierung folgt Phase 4),
**Bußgelder** mit Gesetzes-Referenz und Zahlung als `money.destroy(fine.payment)`,
**Haft** mit server-seitigem Timer, Gefängnis-Geofence und Wiedereinsperren
nach Reconnect.

## Befehle
Alle: `/laws` · `/myfines` · `/payfine <id>`
Polizei: `/fine <id> <lawCode> [notiz]`
Richter (justice Grade 2+): `/lawset <code> <€> <min>` · `/release <id>`
Richter oder Polizei Lieutenant+: `/jail <id> <min> <grund>` (Grund ist Pflicht)

## Live-Tuning
`justice.max_jail_minutes` (120)

## Definition of Done (Phase-3-Scope)
1. Lauffähig ✅ 2. law./justice.-Events, Zahlungen korreliert ✅ 3. Tuning +
Gesetze als Live-Daten ✅ 4. ACP-Datenbasis ✅ 5. Doku ✅ — Verhandlungs-
Terminverwaltung, Bewährung/Fußfessel, Resozialisierungs-Jobs und Pfändung
folgen Phase 4+.
