# Architektur

## 1. Plattform-Entscheidung: FiveM (Lua) statt alt:V

| Kriterium | FiveM | alt:V |
|---|---|---|
| Spielerbasis / Reichweite | sehr groß | deutlich kleiner |
| OneSync Infinity (128+ Slots, Entity-Streaming) | ✅ ausgereift | vergleichbar, kleinere Community |
| Ökosystem (oxmysql, SaltyChat, txAdmin) | ✅ breit & battle-tested | schmaler |
| Typsicherheit | Lua (dynamisch) | TypeScript ✅ |
| Server-Autorität | erreichbar via Konventionen + Convars | ähnlich |

**Entscheidung: FiveM.** Die größere Spielerbasis und das reife Ops-Tooling
(txAdmin, etablierte Voice-Integration) überwiegen den TypeScript-Vorteil von
alt:V. Typsicherheit holen wir teilweise zurück durch: zentrale Schema-Validierung
aller Client-Events im Core, den Log-Event-Katalog als Vertrag und TypeScript im
gesamten Web-/Backend-Stack.

## 2. Systemübersicht

```
┌─────────────┐   HTTPS    ┌──────────┐
│   Spieler    │──────────▶│  Caddy    │──▶ Web (Next.js, Phase 5)
│  (Browser)   │           │  Proxy    │──▶ Backend REST/WS (NestJS)
└─────────────┘           └──────────┘          │
                                                 │
┌─────────────┐  FiveM     ┌──────────────┐     │ internes Docker-Netz
│   Spieler    │──────────▶│  Gameserver   │     │
│  (GTA V)     │           │  (FiveM/Lua)  │     │
└─────────────┘           └──────┬───────┘     │
                                  │ oxmysql      │
                          ┌───────▼──────┐      │
                          │   MariaDB     │◀────┤  (Spiel-Zustand, 3NF)
                          └──────────────┘      │
                                  │ HTTP-Batch   │
                          hrp_logger ────────────▶ /v1/ingest/* (Bearer, intern)
                                                 │
                                          ┌──────▼─────┐   XADD    ┌────────────┐
                                          │   Redis     │──Stream──▶│  Consumer   │
                                          │ (Cache/MQ)  │           │  (Backend)  │
                                          └────────────┘           └──────┬─────┘
                                                                          │ Batch-INSERT
                                                                   ┌──────▼───────┐
                                                                   │ TimescaleDB   │
                                                                   │ (Log-Store,   │
                                                                   │  append-only) │
                                                                   └──────────────┘
```

**Warum TimescaleDB als Log-Store (statt ClickHouse):** SQL-kompatibel (ein
Kompetenz-Stack fürs Team), Hypertables + native Kompression + Retention-Policies
decken 90-Tage-Volllog problemlos ab, JSONB-Payloads mit GIN-Index für den
Log-Explorer. ClickHouse lohnt erst bei >10k Events/s — Migration bleibt möglich,
weil der Event-Envelope storage-agnostisch ist.

**Warum Redis Streams als Message-Queue (statt RabbitMQ):** Redis ist ohnehin für
Cache/Sessions im Stack; Streams mit Consumer-Groups liefern At-least-once-Zustellung,
Dead-Letter und Replay — eine Infrastruktur-Komponente weniger zu betreiben.

## 3. Ordnerstruktur

```
GTA_new/
├── docker-compose.yml         # Gesamte Infrastruktur
├── .env.example               # Konfiguration (kopieren nach .env)
├── proxy/Caddyfile            # Reverse Proxy, HTTPS, Ingest-Block
├── database/
│   ├── migrations/            # MariaDB (Spiel-DB), nummeriert, idempotent via migrate.sh
│   ├── logstore/              # TimescaleDB-Schema (Events, Positionen)
│   └── seeds/                 # RBAC-Matrix, Basis-Items
├── gameserver/
│   ├── Dockerfile             # FiveM-Artefakt-Download + Start
│   ├── server.cfg             # Security-Convars, Ressourcen-Reihenfolge
│   └── resources/[hrp]/
│       ├── hrp_core/          # Framework-Core: Sessions, Security, RBAC, Geld-Basis
│       ├── hrp_logger/        # Log-Pipeline-Client (Queue, Batch, Disk-Buffer, Position-Sampler)
│       ├── hrp_characters/    # Multi-Charakter (3 Slots), Erstellung, Spawn, Save
│       └── hrp_inventory/     # Item-Instanzen, Locations, Gewicht, Lifecycle-Logging
├── backend/                   # NestJS: Ingest → Redis Stream → TimescaleDB-Consumer
├── web/                       # Next.js (Phase 5)
├── ops/backup/                # Backup-Container (voll täglich, inkrementell stündlich)
├── scripts/                   # migrate.sh, restore.sh, seed.sh
└── docs/                      # Dieses Dokument, Event-Katalog, Installation, Betrieb
```

## 4. Framework-Prinzipien

1. **Server-autoritativ:** Kein Client-Event ändert Zustand direkt. Jedes vom
   Client ausgelöste Event läuft durch `HRP.RegisterSecureEvent` (hrp_core):
   Event-Whitelisting, Argument-Schema-Validierung, Rate-Limiting pro
   Spieler+Event, Session-Bindung. Verstöße erzeugen `security.*`-Events.
2. **Log-First:** Module mutieren Zustand ausschließlich über Core-APIs
   (`HRP.Money`, `Inventory.*`), die Mutation + Log-Event atomar koppeln.
   Direkte DB-Schreibzugriffe an diesen APIs vorbei sind verboten (Review-Regel).
3. **Ein Modul = eine Ressource** mit eigenen Tabellen (Prefix-frei, aber im
   Migrations-Ordner dem Modul zugeordnet), eigenen Events (Namespace
   `hrp:<modul>:*`), eigenem README.
4. **Balancing = Daten:** Stellschrauben liegen in Config-Tabellen/Feature-Flags
   (ab Phase 2 via ACP zur Laufzeit änderbar), nicht als Konstanten im Code.
5. **Korrelation:** Zusammengesetzte Transaktionen teilen eine `correlationId`
   (siehe Event-Katalog §1).

## 5. Modul-Übersicht Phase 1

| Modul | Zweck | Tabellen | Events |
|---|---|---|---|
| hrp_core | Sessions, Accounts, Ban-Check, Event-Security, RBAC, Geld-Basis-API | accounts, account_identifiers, sessions, account_bans, roles, permissions, role_permissions, account_roles, character_money | session.*, rbac.*, admin.*, security.*, system.*, money.* |
| hrp_logger | Log-Client: Queue → HTTP-Batch → Backend; Disk-Buffer; Position-Sampler | — (nur Log-Store) | position.batch (+ Transport aller anderen) |
| hrp_characters | Multi-Char (3 Slots), Erstellung mit Pflicht-Lebenslauf, Spawn, periodischer Save, Vitals-Grundgerüst | characters, character_vitals, character_skills | character.* |
| hrp_inventory | Item-Definitionen, Instanzen (UUID, Seriennummer), Locations, Gewichtslimit, Lifecycle | item_definitions, item_instances, item_locations | item.* |
| backend/ingest | Envelope-Validierung, Redis-Stream-Producer | — | — |
| backend/logstore | Stream-Consumer, Batch-Insert, Dead-Letter, Retention-Policies | events, position_samples, money_flow_daily (Timescale) | — |

## 5b. Modul-Übersicht Phase 2

| Modul | Zweck | Tabellen | Events |
|---|---|---|---|
| hrp_core/tuning | Live-Tuning/Feature-Flags: Laufzeit-änderbar, versioniert, Rollback | config_flags, config_flag_history | config.change |
| hrp_economy | Shops mit dynamischen Preisen (Angebot & Nachfrage), Preis-Tick | shops, shop_items | economy.price_tick (+ money.*/item.* korreliert) |
| hrp_jobs | Job-Zuordnung, Grades, Dienststatus, Lohnlauf | jobs, job_grades, character_jobs | job.assign, job.duty, job.payroll |
| hrp_banking | Kontonummern, Ein-/Auszahlung, Überweisung, Daueraufträge | bank_details, standing_orders | bank.standing_order_* (+ money.*) |
| hrp_vehicles | Kauf, Garagen, Schlüssel, Kraftstoff/Kilometer, Persistenz | vehicle_models, vehicles, vehicle_keys | vehicle.* |
| hrp_phone | Rufnummern, Kontakte, SMS | phone_numbers, phone_contacts, phone_messages | comms.sms |

Voice (SaltyChat) wird extern integriert — siehe `docs/voice.md`.

## 5c. Modul-Übersicht Phase 3

| Modul | Zweck | Tabellen | Events |
|---|---|---|---|
| hrp_medical | Verletzungen je Trefferzone, Down/Revive, Krankenakten, Vitals-Simulation | character_injuries, medical_records | combat.damage, combat.down, medical.*, character.state_change |
| hrp_police | MDT-Datenbasis (Access-Log!), Strafregister, Fahndungen, Beweismittelkette | criminal_records, warrants, evidence_cases, evidence_log | police.*, evidence.* |
| hrp_justice | Versioniertes Gesetzbuch, Bußgelder, Haft mit Geofence | laws, law_history, fines, jail_sentences | law.change, justice.* |
| hrp_mechanic | Reparatur (kein Auto-Heal), Rechnungen Spieler-zu-Spieler | — (nutzt vehicles) | vehicle.repair (+ money.transfer) |

## 5d. Modul-Übersicht Phase 4

| Modul | Zweck | Tabellen | Events |
|---|---|---|---|
| hrp_skills | XP nur durch Nutzung, täglicher Decay | character_skills | skill.level_up |
| hrp_resources | Endliche, regenerierende Pools; Ertrag skaliert mit Skill | resource_pools | resource.harvest/depleted |
| hrp_territories | Kontinuierlicher Gang-Einfluss, Verfall, Verkaufs-Modifikator | gangs, gang_members, territories, territory_influence | territory.* |
| hrp_drugs | Kette Anbau→Verarbeitung→Verkauf, rotierende Spots, Spuren | deal_spots | drug.*, crime.trace |
| hrp_director | Gewichtete Zufallsereignisse (Registry), live steuerbar | — | director.event |
| hrp_properties | Kauf, Schlüssel, Routing-Bucket-Interiors, dynamische Preise | properties, property_keys | property.*, door.access |
| hrp_companies | Handelsregister, Ränge, Firmenkonto (Core-Geld-API), Lohnlauf | companies, company_members, company_funds | company.* (+ money.transfer target company) |

## 5e. Modul-Übersicht Phase 5 (Web)

| Modul | Zweck | Events |
|---|---|---|
| backend/auth | Argon2id-Registrierung, Login mit TOTP-2FA, JWT, RBAC-Guard aus der Spiel-DB | web.login, web.mutation |
| backend/ucp | Eigene Daten: Dashboard, Skills/Bußgelder, Kontoauszug (Log-Store) | — |
| backend/acp | Log-Explorer, Timeline, Korrelation, Geldfluss (n Hops), Item-Trace, Replay-Daten, 360°-Akte, Tuning-API | admin.access (JEDER Lesezugriff), config.change |
| backend/acp/anomaly | Regelbasierte Erkennung (Geldzuwachs, Admin-Vergaben, Drogenumsatz) + Prüf-Queue | anomaly.detected |
| web/ | Next.js: Homepage, Login/Register, UCP, ACP-Oberflächen | — |

ACP-Tuning-Änderungen schreibt das Backend in `config_flags`; der Gameserver
pollt den Stand alle 60 s (hrp_core/tuning) — Änderungen ohne Restart wirksam.

## 5f. Härtung (Phase 6)

| Baustein | Beschreibung |
|---|---|
| hrp_anticheat | Teleport-/Godmode-/Entity-/Explosions-Checks, Strike-System, `AllowTeleport`-Anmeldung legitimer Teleports; Kick-Schwelle per Tuning (Default: nur loggen) |
| Log-Audit | `scripts/audit-log-completeness.sh`: geschützte Tabellen nur via Core-APIs beschreibbar, alle reason-Codes registriert — CI-Gate |
| Lasttest | `scripts/loadtest/ingest-load.js`: 2.000 Events/s-Abnahme mit p95-Kriterium |
| OpenAPI | `/api-docs` (abschaltbar via `API_DOCS=0`) |
| CI | GitHub Actions: Backend-Build+Tests, Web-Build, Lua-Syntax+Tests+Audit |
| Launch | `docs/launch-checklist.md` — 9 Abschnitte bis zur Whitelist-Öffnung |

## 6. Sicherheits-Grundlagen (Phase 1 aktiv)

- `server.cfg`: `sv_scriptHookAllowed 0`, `sv_enforceGameBuild`, OneSync on,
  `sv_filterRequestControl 4` (Entity-Lockdown-Basis), FiveM-Rate-Limiter-Convars.
- Alle DB-Zugriffe über oxmysql mit Platzhaltern (Prepared Statements).
- Ingest-Endpunkt: nur internes Docker-Netz + Bearer-Token, öffentlich vom Proxy geblockt.
- Passwörter (UCP, Phase 5): Argon2id; 2FA TOTP; ACP zusätzlich IP-Allowlist — Schema-Felder existieren bereits.
- Admin-Aktionen in-game nur mit RBAC-Permission, jede Nutzung → `admin.action`-Event.
