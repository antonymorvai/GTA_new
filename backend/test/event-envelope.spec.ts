import {
  categoryOf,
  EventEnvelopeSchema,
  IngestBatchSchema,
} from '../src/common/event-envelope';

const validEvent = {
  eventId: '6f1c2a9e-1234-4abc-9def-0123456789ab',
  ts: 1751490000123,
  type: 'money.transfer',
  schemaVersion: 1,
  serverId: 'main',
  actor: { accountId: 42, characterId: 1337, sessionId: '6f1c2a9e-1234-4abc-9def-0123456789ac' },
  target: { kind: 'character', id: '2001' },
  context: { pos: { x: 215.3, y: -810.1, z: 30.7 }, instance: null },
  correlationId: '6f1c2a9e-1234-4abc-9def-0123456789ad',
  payload: { amount: 5000, reason: 'trade.direct' },
};

describe('EventEnvelopeSchema (Log-Event-Katalog §1)', () => {
  it('akzeptiert ein vollständiges Katalog-Event', () => {
    expect(EventEnvelopeSchema.parse(validEvent).type).toBe('money.transfer');
  });

  it('akzeptiert minimale Events (System ohne actor)', () => {
    const minimal = {
      eventId: validEvent.eventId,
      ts: 1,
      type: 'system.resource_start',
      payload: { resource: 'hrp_core' },
    };
    const parsed = EventEnvelopeSchema.parse(minimal);
    expect(parsed.schemaVersion).toBe(1);
    expect(parsed.serverId).toBe('main');
  });

  it.each([
    ['fehlende eventId', { ...validEvent, eventId: undefined }],
    ['eventId keine UUID', { ...validEvent, eventId: 'nope' }],
    ['ts fehlt', { ...validEvent, ts: undefined }],
    ['ts negativ', { ...validEvent, ts: -5 }],
    ['type ohne Namespace', { ...validEvent, type: 'moneytransfer' }],
    ['type mit Großbuchstaben', { ...validEvent, type: 'Money.Transfer' }],
  ])('lehnt ab: %s', (_label, event) => {
    expect(EventEnvelopeSchema.safeParse(event).success).toBe(false);
  });

  it('lehnt leere und übergroße Batches ab', () => {
    expect(IngestBatchSchema.safeParse({ events: [] }).success).toBe(false);
    const tooMany = { events: Array.from({ length: 501 }, () => validEvent) };
    expect(IngestBatchSchema.safeParse(tooMany).success).toBe(false);
    expect(IngestBatchSchema.safeParse({ events: [validEvent] }).success).toBe(true);
  });

  it('leitet die Kategorie aus dem Typ ab', () => {
    expect(categoryOf('money.transfer')).toBe('money');
    expect(categoryOf('position.batch')).toBe('position');
  });
});
