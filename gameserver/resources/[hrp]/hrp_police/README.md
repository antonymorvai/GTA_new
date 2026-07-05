# hrp_police

Polizei: MDT-Datenbasis, Strafregister, Fahndungen, Beweismittelkette.
**Jeder MDT-Zugriff — auch reines Nachschlagen — erzeugt `police.mdt_access`**
(In-RP-Spiegel des ACP-Access-Logs). Das MDT-NUI folgt in Phase 5 auf
derselben Datenbasis.

## Beweismittelkette (Chain of Custody)
Beweise sind normale Item-Instanzen im Container `evidence:<fallnummer>`.
Jede Ein-/Auslagerung erzeugt drei Spuren: `item.move` (Item-Trace),
`evidence.custody` (Log-Store) und eine `evidence_log`-Zeile (In-RP-Akte).
Entnahme (`/evtake`) erst ab Sergeant und immer protokolliert.

## Befehle (Polizei im Dienst)
`/mdt <vor> <nach>` · `/platecheck <kz>` · `/serialcheck <sn>` ·
`/charge <id> <lawCode> [notiz]` · `/warrant <vor> <nach> <grund>` (Sergeant+) ·
`/warrantclose <id> <executed|revoked>` (Sergeant+) ·
`/newcase <titel>` · `/evstore <fall> <uuid> [notiz]` · `/evtake` (Sergeant+) · `/evlist <fall>`

## Definition of Done (Phase-3-Scope)
1. Lauffähig ✅ 2. police./evidence.-Events inkl. Access-Logging ✅
3. (Berechtigungen über Job-Grades, Daten) ✅ 4. ACP-Datenbasis ✅ 5. Doku ✅ —
Spurensicherung (Fingerabdrücke/DNA/Ballistik), Funkzellenabfrage mit
richterlichem Beschluss, Blitzer und SWAT folgen Phase 4+.
