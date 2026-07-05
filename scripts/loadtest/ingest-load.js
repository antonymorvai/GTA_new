#!/usr/bin/env node
/**
 * Lasttest für die Log-Pipeline (Ingest -> Redis Stream -> TimescaleDB).
 * Simuliert Gameserver-Batches. Nur Node 20+ nötig, keine Abhängigkeiten.
 *
 * Nutzung:
 *   INGEST_URL=http://localhost:3001/v1/ingest/events \
 *   INGEST_TOKEN=<token> \
 *   node scripts/loadtest/ingest-load.js [eventsProSekunde=2000] [dauerSekunden=60]
 *
 * Erfolgskriterium (128-Slot-Ziel): 2.000 Events/s über 60 s ohne Fehler,
 * Stream-Backlog (XLEN hrp:events) fällt nach dem Test binnen 60 s auf ~0.
 */

const url = process.env.INGEST_URL ?? 'http://localhost:3001/v1/ingest/events';
const token = process.env.INGEST_TOKEN ?? '';
const eventsPerSecond = Number(process.argv[2] ?? 2000);
const durationSeconds = Number(process.argv[3] ?? 60);
const BATCH_SIZE = 100;

function makeEvent(i) {
  const types = ['money.transfer', 'item.move', 'character.save', 'vehicle.enter', 'comms.sms'];
  return {
    eventId: crypto.randomUUID(),
    ts: Date.now(),
    type: types[i % types.length],
    schemaVersion: 1,
    serverId: 'loadtest',
    actor: { accountId: 1 + (i % 128), characterId: 1000 + (i % 128) },
    context: { pos: { x: Math.random() * 5000 - 2500, y: Math.random() * 5000 - 2500, z: 30 } },
    payload: { loadtest: true, seq: i, amount: 1000 + (i % 5000), reason: 'trade.direct' },
  };
}

async function main() {
  const batchesPerSecond = Math.ceil(eventsPerSecond / BATCH_SIZE);
  let sent = 0, failed = 0, latencies = [];
  console.log(`Ziel: ${eventsPerSecond} Events/s (${batchesPerSecond} Batches/s) über ${durationSeconds} s -> ${url}`);

  const end = Date.now() + durationSeconds * 1000;
  let seq = 0;

  while (Date.now() < end) {
    const tickStart = Date.now();
    const jobs = [];
    for (let b = 0; b < batchesPerSecond; b++) {
      const events = Array.from({ length: BATCH_SIZE }, () => makeEvent(seq++));
      const t0 = performance.now();
      jobs.push(
        fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ events }),
        }).then((res) => {
          latencies.push(performance.now() - t0);
          if (res.ok) sent += BATCH_SIZE; else failed += BATCH_SIZE;
        }).catch(() => { failed += BATCH_SIZE; }),
      );
    }
    await Promise.all(jobs);
    const elapsed = Date.now() - tickStart;
    if (elapsed < 1000) await new Promise((r) => setTimeout(r, 1000 - elapsed));
  }

  latencies.sort((a, b) => a - b);
  const p = (q) => latencies[Math.floor(latencies.length * q)]?.toFixed(1) ?? '-';
  console.log(`\nGesendet: ${sent} Events · Fehlgeschlagen: ${failed}`);
  console.log(`Batch-Latenz ms — p50: ${p(0.5)} · p95: ${p(0.95)} · p99: ${p(0.99)}`);
  console.log('\nNachlauf prüfen:');
  console.log('  docker compose exec redis redis-cli -a $REDIS_PASSWORD XLEN hrp:events');
  console.log("  docker compose exec logstore psql -U $LOGSTORE_USER -d $LOGSTORE_DB -c \"SELECT count(*) FROM events WHERE server_id='loadtest';\"");
  process.exit(failed > 0 ? 1 : 0);
}

void main();
