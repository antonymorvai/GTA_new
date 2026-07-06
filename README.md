# HardcoreRP — GTA5-Roleplay-Server (Hardcore-Realismus)

Eigenes, modulares FiveM-Framework mit **totaler Nachverfolgbarkeit**
(Event-Sourcing der kompletten Spielwelt) und **dynamischer Spielwelt**
(kein statischer Wert, wo ein dynamisches System möglich ist).

## Status: Alle 6 Phasen ✅ (Fundament · Kernsysteme · Fraktionen · Dynamik · Web · Härtung)

| Baustein | Stand |
|---|---|
| Docker-Infrastruktur (MariaDB, Redis, TimescaleDB, Backend, Proxy, Backups) | ✅ |
| Log-Pipeline (Queue → Redis Streams → TimescaleDB, Disk-Buffer, Dead-Letter) | ✅ |
| Log-Event-Katalog | ✅ [docs/log-event-catalog.md](docs/log-event-catalog.md) |
| Framework-Core (Sessions, Event-Security, RBAC, Geld-Basis-API) | ✅ |
| Charaktersystem (3 Slots, Pflicht-Lebenslauf, NUI-Auswahl) | ✅ |
| Inventar-Basis (Item-Instanzen mit UUID/Seriennummer, Item-Trace-Datenbasis) | ✅ |
| Positions-Sampling (Bewegungs-Replay-Datenbasis, 5-s-Intervall) | ✅ |
| Backups (täglich voll, stündlich inkrementell, Point-in-Time-Restore) | ✅ |
| Live-Tuning/Feature-Flags (Laufzeit-änderbar, versioniert, Rollback) | ✅ |
| Wirtschafts-Engine (dynamische Shop-Preise, Geldmengen-Aggregat) | ✅ |
| Bank (Konten, Überweisungen, Daueraufträge) + Jobs-Grundgerüst (Lohnlauf) | ✅ |
| Fahrzeuge (Kauf, Garagen, Schlüssel, Kraftstoff/Kilometer, Persistenz) | ✅ |
| Smartphone-Basis (Rufnummern, Kontakte, SMS mit comms.sms) | ✅ |
| Voice | 📋 Integrations-Guide [docs/voice.md](docs/voice.md) (SaltyChat, lizenzbedingt extern) |
| Verletzungssystem (Trefferzonen, Bewusstlosigkeit statt Respawn, Krankenakten, Vitals) | ✅ |
| Polizei (MDT-Datenbasis mit Access-Log, Strafregister, Fahndungen, Beweismittelkette) | ✅ |
| Justiz (versioniertes Gesetzbuch, Bußgelder, Haft mit Geofence) | ✅ |
| Mechaniker (Reparatur ohne Auto-Heal, Rechnungssystem) | ✅ |
| Skills (XP nur durch Nutzung, Decay bei Nichtnutzung) | ✅ |
| Dynamische Ressourcen (endliche, regenerierende Pools) | ✅ |
| Territorien (kontinuierlicher Gang-Einfluss mit Verfall) | ✅ |
| Illegale Kette (Anbau → Verarbeitung → rotierende Deal-Spots, Spuren) | ✅ |
| World Director (gewichtete Zufallsereignisse, live steuerbar) | ✅ |
| Immobilien (Kauf, Routing-Bucket-Interiors, dynamische Preise, door.access) | ✅ |
| Firmen (Handelsregister, Firmenkonto via Geld-API, Lohnlauf) | ✅ |
| Web-Auth (Argon2id, TOTP-2FA, JWT, web.login-Events) | ✅ |
| Homepage (Next.js, Regelwerk, Impressum/Datenschutz) | ✅ |
| UCP (Dashboard, Charaktere, Kontoauszug aus dem Log-Store) | ✅ |
| ACP: Log-Explorer, Universal-Timeline, Korrelations-Drill-Down | ✅ |
| ACP: 360°-Spielerakte, Item-Trace, Geldfluss-Analyse (n Hops) | ✅ |
| ACP: Anomalie-Erkennung (3 Regeln) + Prüf-Queue | ✅ |
| ACP: Live-Tuning-Editor mit Historie (Gameserver übernimmt in 60 s) | ✅ |
| Session-Replay-API (Bewegungsdaten je Zeitfenster) | ✅ (Kartenansicht = Ausbaustufe) |
| Anti-Cheat (Teleport/Godmode/Entity-Blacklist/Explosionen, Strike-System) | ✅ |
| Log-Vollständigkeits-Audit (statisch, läuft in CI) | ✅ `scripts/audit-log-completeness.sh` |
| Lasttest-Skript (2.000 Events/s-Abnahme) | ✅ `scripts/loadtest/` |
| OpenAPI (`/api-docs`), CI (Backend/Web/Lua+Audit) | ✅ |
| Launch-Checkliste | ✅ [docs/launch-checklist.md](docs/launch-checklist.md) |
| Whitelist-Bewerbung (Fragebogen + server-bewerteter Regeltest) + ACP-Review | ✅ |
| Ticketsystem & Spielerreports (UCP + ACP-Queue, Beweis-Felder) | ✅ |
| Sanktions-Workflow im ACP (Begründungs- + Beweis-Pflicht, Historie) | ✅ |
| Session-Replay-Kartenansicht (Route abspielen, Zeit-Slider) | ✅ |
| Kill-Akte (Down + Schäden + Bewegungspfade Opfer/Täter auf Karte) | ✅ |
| Live-Karte (aktive Charaktere, 5-s-Refresh) + Homepage-Live-Status | ✅ |
| In-Game-HUD (Vitals, Tank, Tacho) + Inventar-NUI (F2) | ✅ |
| Discord-Alerts (Anti-Cheat, Bans, Anomalien, Fehler — throttled) | ✅ |
| Waffen als Item-Instanzen (Ausrüsten, Munition, Schusszähler/Ballistik) | ✅ |
| Crafting (DB-Rezepte, Skill-Freischaltung, Qualität) | ✅ |
| Wetterfronten + synchrone Uhr (Glätte bei Regen, ACP-Override) | ✅ |
| Fahrzeug-Verschleiß mit Wartungsintervall (/service) | ✅ |
| Regierung: Gesetzgebung (Entwurf → Abstimmung → Inkrafttreten) + Wahlen (geheim) | ✅ |
| Drogen-Konsum & Sucht (Toleranz, Entzug, Abstinenz-Heilung) | ✅ |
| Crafting-Werkzeuge mit Verschleiß + Werkbank-Pflicht | ✅ |
| Jahreszeiten (Schnee im Winter, saisonale Ernteerträge) | ✅ |
| Kredite mit Bonität aus echten Verhaltensdaten (Raten, Ausfall) | ✅ |
| Blitzer mit automatischem Bußgeld-Workflow | ✅ |
| Lieferketten: Tankstellen-Bestände + Trucker-Belieferung (leere Station = kein Sprit) | ✅ |
| Twitter-Klon + Kleinanzeigen (IC-Handles, Gebühr, Volltext-Logging) | ✅ |
| KFZ-Versicherung + Totalschaden (Vollkasko/Teilkasko/Haftpflicht, Prämien-Einzug, /claim, /scrap) | ✅ |
| 20-Punkte-Sprint: Einbruch, Immobilien-Lager, Kofferraum, Hehler, Drop-Despawn, Übergewicht, Klinikkosten | ✅ |
| 20-Punkte-Sprint: Funk (SaltyChat-Brücke, Staatskanäle), Tuning, Ausdauer, Geldtransport-Raub, HUD-Uhr, /help | ✅ |
| 20-Punkte-Sprint: Vermögenssteuer, /wanted, Zeitung (in-game + Web), Anomalie-Regel Transfer-Ring | ✅ |
| 20-Punkte-Sprint: UCP-Strafregister, ACP-Heatmap, Log-CSV-Export | ✅ |

## Dokumentation

- **[🗺 Die vollständige Roadmap](docs/roadmap.md)** — der Nordstern: Design-Verfassung, Community-Erkenntnisse, alle geplanten Features in 3 Horizonten
- [Architektur & Plattform-Entscheidung (FiveM)](docs/architecture.md)
- [Log-Event-Katalog v1](docs/log-event-catalog.md) — der Vertrag aller Module
- [Installation von Null bis Live](docs/installation.md)
- [Betriebs-Handbuch (Backups, Monitoring, DSGVO)](docs/operations.md)
- README je Modul: `gameserver/resources/[hrp]/*/README.md`

## Kernprinzipien

1. **Server-autoritativ:** Der Client vertraut niemals sich selbst. Jedes
   Client-Event läuft durch Whitelisting, Schema-Validierung, Rate-Limiting
   und Session-Bindung (`hrp_core/server/security.lua`).
2. **Log-First:** Keine Geld- oder Item-Mutation ohne unveränderliches Event
   mit registriertem Grund-Code. Der Log-Store ist append-only.
3. **Definition of Done je Modul:** lauffähig + getestet, alle Mutationen
   loggen nach Katalog, Balancing-Werte steuerbar, ACP-Datenbasis vorhanden,
   Doku vollständig.

## Schnellstart

```bash
cp .env.example .env            # Secrets setzen!
docker compose up -d mariadb logstore redis
./scripts/migrate.sh && ./scripts/seed.sh
docker compose up -d backend proxy backup
docker compose --profile game up -d fivem
```

Details: [docs/installation.md](docs/installation.md)

## Tests

```bash
cd backend && npm install && npm test
```

Abgedeckt: Envelope-Validierung gegen den Event-Katalog und
Log-Vollständigkeit des Timescale-Writers (kein Event geht verloren).
