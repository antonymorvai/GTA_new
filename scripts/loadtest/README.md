# Lasttests

## Log-Pipeline (`ingest-load.js`)

Simuliert die Event-Last eines vollen 128-Slot-Servers gegen den
Ingest-Endpunkt (ohne Gameserver). Node 20+, keine Abhängigkeiten.

```bash
INGEST_URL=http://localhost:3001/v1/ingest/events \
INGEST_TOKEN=$(grep INGEST_TOKEN .env | cut -d= -f2) \
node scripts/loadtest/ingest-load.js 2000 60
```

**Abnahmekriterien (Launch-Checkliste):**
1. 2.000 Events/s über 60 s, 0 fehlgeschlagene Batches
2. Batch-Latenz p95 < 250 ms
3. `XLEN hrp:events` fällt nach Testende binnen 60 s auf ~0 (Consumer kommt nach)
4. Event-Anzahl in TimescaleDB == gesendete Anzahl (At-least-once, Dedup via event_id)

Zur Einordnung: 128 Spieler erzeugen im Normalbetrieb grob 100–300 Events/s
(inkl. Positions-Batches) — der Test fährt das ~10-fache.

## Testdaten aufräumen

Loadtest-Events sind über `server_id='loadtest'` markiert. Auf Produktions-
systemen den Test NICHT gegen den Live-Store fahren; auf Staging genügt die
Retention zum Aufräumen.
