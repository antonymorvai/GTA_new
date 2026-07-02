# hrp_jobs

Jobs-Grundgerüst: ein Job pro Charakter, Grades mit Gehalt, Dienststatus,
automatischer Lohnlauf (zahlt nur **im Dienst**, aufs Bankkonto, als
`money.create(state.salary)` mit Payroll-Korrelation).

## Nutzung
- `/setjob <serverId> <job> [grade]` — Permission `game.admin.job_set`, geloggt
- `/duty` — Dienst an/aus (`job.duty`-Event)
- Exports: `GetJob(characterId)`, `SetJob(characterId, job, grade, byAccountId, src)`

## Live-Tuning
`jobs.salary_interval_minutes` (30) · `jobs.salary_multiplier` (1.0 — Kopplung
an Staatskasse ersetzt den Multiplikator in Phase 4).

## Definition of Done (Phase-2-Scope)
1. Lauffähig ✅ 2. `job.assign/duty/payroll` + `money.*` ✅ 3. Tuning ✅
4. ACP-Datenbasis ✅ 5. Doku ✅ — Fraktions-Features (MDT, Dienstpläne) folgen Phase 3.
