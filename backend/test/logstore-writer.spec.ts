import { LogstoreWriter } from '../src/logstore/logstore.writer';
import { EventEnvelope } from '../src/common/event-envelope';

/**
 * Log-Vollständigkeits-Test (DoD Regel 2): Der Writer darf kein Event
 * verlieren — reguläre Events landen in `events`, position.batch wird
 * vollständig in position_samples entrollt.
 */
describe('LogstoreWriter.writeBatch', () => {
  function makeWriter() {
    const writer = new LogstoreWriter();
    const queries: Array<{ sql: string; values: unknown[] }> = [];
    // pg-Pool durch Mock ersetzen
    (writer as unknown as { pool: unknown }).pool = {
      query: async (sql: string, values: unknown[]) => {
        queries.push({ sql, values });
        return { rows: [] };
      },
    };
    return { writer, queries };
  }

  const base: EventEnvelope = {
    eventId: '6f1c2a9e-1234-4abc-9def-0123456789ab',
    ts: 1751490000123,
    type: 'item.create',
    schemaVersion: 1,
    serverId: 'main',
    payload: { uuid: 'abc' },
  };

  it('schreibt reguläre Events als eine Batch-INSERT-Query', async () => {
    const { writer, queries } = makeWriter();
    await writer.writeBatch([base, { ...base, type: 'money.create' }]);

    expect(queries).toHaveLength(1);
    expect(queries[0].sql).toContain('INSERT INTO events');
    // 16 Spalten * 2 Events
    expect(queries[0].values).toHaveLength(32);
  });

  it('entrollt position.batch vollständig in position_samples', async () => {
    const { writer, queries } = makeWriter();
    const posEvent: EventEnvelope = {
      ...base,
      type: 'position.batch',
      payload: {
        samples: [
          { characterId: 1, x: 1, y: 2, z: 3, heading: 90, speed: 5 },
          { characterId: 2, x: 4, y: 5, z: 6 },
        ],
      },
    };
    await writer.writeBatch([posEvent]);

    expect(queries).toHaveLength(1);
    expect(queries[0].sql).toContain('INSERT INTO position_samples');
    expect(queries[0].values).toHaveLength(16); // 8 Spalten * 2 Samples
  });

  it('mischt beide Typen ohne Verlust', async () => {
    const { writer, queries } = makeWriter();
    const posEvent: EventEnvelope = {
      ...base,
      type: 'position.batch',
      payload: { samples: [{ characterId: 1, x: 1, y: 2, z: 3 }] },
    };
    await writer.writeBatch([base, posEvent, { ...base, type: 'session.drop' }]);

    const tables = queries.map((q) => q.sql.match(/INSERT INTO (\w+)/)?.[1]);
    expect(tables.sort()).toEqual(['events', 'position_samples']);
  });

  it('ignoriert defekte Samples statt zu crashen', async () => {
    const { writer, queries } = makeWriter();
    const posEvent: EventEnvelope = {
      ...base,
      type: 'position.batch',
      payload: { samples: [{ x: 1, y: 2, z: 3 }, { characterId: 7, x: 1, y: 2, z: 3 }] },
    };
    await writer.writeBatch([posEvent]);
    expect(queries[0].values).toHaveLength(8); // nur das valide Sample
  });
});
