# hrp_logger

Log-Pipeline-Client. Transportiert alle Events des Servers asynchron und
verlustfrei in den Log-Store (siehe `docs/log-event-catalog.md`).

## Exports (server)

| Export | Beschreibung |
|---|---|
| `Log(type, data)` | Event einreihen (nie blockierend). `data`: `{actor, target, pos, instance, correlationId, payload}` |
| `NewCorrelationId()` | UUID für Multi-Event-Transaktionen |
| `IsHealthy()` | `false`, wenn Backend aktuell nicht erreichbar (Events laufen dann in den Disk-Buffer) |

## Convars (server.cfg)

| Convar | Default | Beschreibung |
|---|---|---|
| `hrp_ingest_url` | `http://backend:3001/v1/ingest/events` | Backend-Ingest (nur internes Netz!) |
| `hrp_ingest_token` | – | Bearer-Token, muss `INGEST_TOKEN` aus `.env` entsprechen |
| `hrp_server_id` | `main` | Kennung bei Multi-Server-Betrieb |
| `hrp_position_interval` | `5000` | Positions-Sampling in ms |

## Zustellgarantie

Queue → Batch (2 s / 100 Events) → HTTP → Redis Stream → TimescaleDB.
Bei Versand-Fehler: Disk-Buffer `buffer/pending.jsonl`, automatisches Nachspielen
bei Wiederverfügbarkeit sowie beim Ressourcen-Start. Notbremse bei 50.000
gepufferten Zeilen (dann laut Konsolen-Alarm).

## Definition of Done (Phase-1-Scope)

1. Lauffähig ✅ (nur Convars nötig) 2. Loggt selbst `system.*` ✅
3. Sampling-Intervall via Convar (ACP-Live-Tuning folgt Phase 2) ✅
4. ACP-Ansicht: Log-Explorer (Phase 5) — Daten liegen bereits vollständig vor ✅
5. Doku ✅
