# Launch-Checkliste

Abarbeiten in dieser Reihenfolge. Jeder Punkt muss abgehakt sein, bevor die
Whitelist geöffnet wird.

## 1. Infrastruktur & Secrets
- [ ] Server dimensioniert (4+ Kerne, 16 GB RAM, SSD), Docker + Compose v2
- [ ] `.env` aus `.env.example` erstellt, ALLE `change-me`-Werte ersetzt (`openssl rand -hex 32`)
- [ ] `DOMAIN` gesetzt, DNS-A-Record zeigt auf den Server, HTTPS-Zertifikat wird ausgestellt (Caddy-Log prüfen)
- [ ] Firewall: nur 80/443 + 30120 (TCP/UDP) öffentlich; **40120 (txAdmin) nur Admin-IPs/VPN**
- [ ] `FIVEM_LICENSE_KEY` gültig, `FIVEM_GAME_BUILD` aktuell, Artefakt-URL im Gameserver-Dockerfile gepinnt

## 2. Datenbanken
- [ ] `./scripts/migrate.sh` fehlerfrei (Spiel-DB + Log-Store, inkl. Anomalie-Tabelle)
- [ ] `./scripts/seed.sh` eingespielt (RBAC, Items, Shops, Jobs, Gesetzbuch, Pools, Territorien)
- [ ] Retention konfiguriert (`LOG_RETENTION_DAYS`, `POSITION_RETENTION_DAYS`) und im Backend-Log bestätigt

## 3. Log-Pipeline (Kernprinzip A — ohne das kein Launch)
- [ ] Testjoin erzeugt `session.connect` in TimescaleDB (Kommandos: docs/installation.md §7)
- [ ] `position.batch` wird entrollt (`SELECT count(*) FROM position_samples`)
- [ ] Dead-Letter leer (`XLEN hrp:events:dead` = 0)
- [ ] Disk-Buffer-Test: Backend stoppen → spielen → Backend starten → Events kommen nach, nichts fehlt
- [ ] `./scripts/audit-log-completeness.sh` bestanden (läuft auch in der CI)

## 4. Lasttest (scripts/loadtest/README.md)
- [ ] 2.000 Events/s über 60 s: 0 Fehler, p95 < 250 ms
- [ ] Stream-Backlog nach Test binnen 60 s abgebaut
- [ ] Timescale-Eventanzahl == gesendete Anzahl

## 5. Backups & Restore (docs/operations.md)
- [ ] Voll-Backup manuell ausgelöst und Datei geprüft
- [ ] Inkrementelles Binlog-Backup läuft stündlich
- [ ] **Restore-PROBE in Wegwerf-Umgebung durchgeführt** (Voll + Point-in-Time)
- [ ] Off-site-Kopie eingerichtet (rsync/Objektspeicher)

## 6. Sicherheit
- [ ] Whitelist aktiv (`hrp_whitelist_enforce 1`)
- [ ] Erster Admin über Konsole gesetzt (`hrp_grantrole <id> management`), KEINE weiteren Konsolen-Grants
- [ ] ACP-Login mit 2FA für alle Teammitglieder erzwungen (organisatorisch; Rollen erst nach 2FA-Setup vergeben)
- [ ] Anti-Cheat-Tuning entschieden: `anticheat.kick_strikes` (Empfehlung Launch: 5), `anticheat.cancel_explosions` (Empfehlung: true)
- [ ] Ingest öffentlich geblockt (curl auf `https://DOMAIN/api/v1/ingest/events` → 403)
- [ ] `API_DOCS=0` in Produktion setzen ODER bewusst offen lassen (nur Pfad-Übersicht, keine Secrets)

## 7. Recht & Inhalte (docs/…, web/)
- [ ] Impressum + Datenschutzerklärung mit echten Betreiberdaten befüllt (`web/app/impressum`, `web/app/datenschutz`)
- [ ] Regelwerk final (web/app/regelwerk), Team informiert
- [ ] Keine kopierten Marken-Assets im Repo/auf dem Server; Monetarisierung (falls geplant) nur kosmetisch (Cfx.re-ToS)
- [ ] DSGVO: Auskunfts-/Löschprozess dem Team bekannt (docs/operations.md)

## 8. Betrieb
- [ ] Monitoring-Runbook durchgespielt (Stream-Backlog, Pending, Dead-Letter, Insert-Rate)
- [ ] Anomalie-Scan läuft (Backend-Log: „Anomalie(n) in der Prüf-Queue" bzw. leerer Scan)
- [ ] Director-Gewichte/Wirtschafts-Parameter im ACP gesichtet (Tuning-Seite zeigt alle Flags)
- [ ] Eskalationsplan: Wer reagiert auf Anti-Cheat-Alerts / Anomalien / Ausfälle?

## 9. Soft-Launch
- [ ] 1–2 Wochen begrenzte Whitelist (Team + Vertrauensspieler)
- [ ] Täglich: Geldmengen-Bilanz prüfen (`money_flow_daily`: created vs. destroyed)
- [ ] Balancing über ACP-Tuning nachziehen (keine Code-Deploys für Zahlenwerte!)
- [ ] Danach: Whitelist öffnen 🎉
