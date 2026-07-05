# HardcoreRP — GTA5-Roleplay-Server (Hardcore-Realismus)

Eigenes, modulares FiveM-Framework mit **totaler Nachverfolgbarkeit**
(Event-Sourcing der kompletten Spielwelt) und **dynamischer Spielwelt**
(kein statischer Wert, wo ein dynamisches System möglich ist).

## Status: Phasen 1–4 ✅ (Fundament · Kernsysteme · Fraktionen · Dynamik)

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

Folgephasen: 5 Web (Homepage, UCP, ACP mit Timeline/Geldfluss-Graph/
Session-Replay/Anomalie-Queue) · 6 Härtung (Anti-Cheat, Lasttests,
Log-Vollständigkeits-Audit, Launch-Checkliste).

## Dokumentation

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
