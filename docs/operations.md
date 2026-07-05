# Betriebs-Handbuch

## Backups

| Was | Wann | Wie | Aufbewahrung |
|---|---|---|---|
| Spiel-DB voll | täglich 04:00 (`BACKUP_FULL_CRON`) | `mariadb-dump --single-transaction --flush-logs` | 14 Tage |
| Spiel-DB inkrementell | stündlich (`BACKUP_INCR_CRON`) | Binlog-Rotation + `mariadb-binlog --raw` | 7 Tage |
| Log-Store voll | täglich 04:00 | `pg_dump -Fc` | 14 Tage |

Backups liegen unter `./backups/` (Volume). **Zusätzlich off-site kopieren**
(rsync/objektspeicher) — ein Backup auf derselben Maschine ist kein Backup.

### Restore
- Voll: `./scripts/restore.sh backups/game/full_<stamp>.sql.gz`
- Point-in-Time: `./scripts/restore.sh <voll> "2026-07-02 14:30:00"`
- Log-Store: `pg_restore` (Kommando im Kopf von `scripts/restore.sh`)
- **Restore-Probe mindestens monatlich** in einer Wegwerf-Umgebung durchführen.

## Log-Pipeline überwachen

| Prüfung | Kommando / Erwartung |
|---|---|
| Stream-Backlog | `XLEN hrp:events` — dauerhaft > 10.000 ⇒ Consumer prüfen |
| Pending | `XPENDING hrp:events logstore-writers` — alte Einträge ⇒ Consumer hängt |
| Dead-Letter | `XLEN hrp:events:dead` — > 0 ⇒ Events analysieren (Schema-Drift?) |
| Disk-Buffer Gameserver | Konsolen-Warnung `[hrp_logger]` + Datei `buffer/pending.jsonl` |
| Insert-Rate | `SELECT count(*) FROM events WHERE time > now() - interval '5 min';` |

Bei Backend-Ausfall puffert der Gameserver lokal (bis 50.000 Zeilen) und spielt
automatisch nach — es geht nichts verloren, solange der Ausfall < Puffergröße bleibt.

## Retention & DSGVO

- Automatisch: `LOG_RETENTION_DAYS` (90) / `POSITION_RETENTION_DAYS` (30) als
  Timescale-Retention-Policies, gesetzt beim Backend-Start.
- Auskunft (Art. 15): Alle Events eines Accounts:
  `SELECT * FROM events WHERE actor_account = $1 ORDER BY time;`
- Löschung (Art. 17): Einzelfall-Löschung erfolgt bewusst NICHT über die
  App-Rolle (append-only), sondern als dokumentierter Admin-Eingriff mit dem
  Superuser. Jeden Eingriff im Team-Wiki protokollieren (wer, wann, Betroffener,
  Rechtsgrund). Spiel-DB: Accounts werden anonymisiert (username/email/license
  → `deleted_<id>`), nicht gelöscht, um Fremd-Referenzen (Logs anderer Spieler)
  konsistent zu halten.

## Sicherheit im Betrieb

- txAdmin-Port 40120 niemals öffentlich — Firewall auf Admin-IPs/VPN.
- `INGEST_TOKEN` und DB-Passwörter rotieren: `.env` ändern → `docker compose up -d`
  (Gameserver-Neustart in Wartungsfenster, da Convar beim Start gesetzt wird).
- Admin-Bootstrap nur über Server-Konsole (`hrp_grantrole`), nie über Chat-Befehle.
- Admin-Log-Kontrolle: `SELECT * FROM events WHERE category='admin' ORDER BY time DESC;`
  — diese Events sind append-only und für niemanden unterhalb DB-Superuser löschbar.

## Updates

1. `git pull`
2. Neue Migrations? → Wartungsfenster: `./scripts/migrate.sh`
3. `docker compose build backend && docker compose up -d backend`
4. Gameserver-Ressourcen: `restart hrp_<modul>` in der Konsole oder Server-Neustart.
5. FiveM-Artefakt aktualisieren: `docker compose build fivem` (Artefakt-URL pinnen!).
