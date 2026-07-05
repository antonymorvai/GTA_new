import { z } from 'zod';

/**
 * Event-Envelope — muss docs/log-event-catalog.md §1 entsprechen.
 * Bewusst tolerant bei payload (typ-spezifische Schemata werden je Modul
 * dokumentiert); streng bei Envelope-Pflichtfeldern.
 */
export const EventEnvelopeSchema = z.object({
  eventId: z.string().uuid(),
  ts: z.number().int().positive(),
  type: z
    .string()
    .min(3)
    .max(64)
    .regex(/^[a-z_]+\.[a-z_]+$/, 'type muss dem Muster namespace.aktion folgen'),
  schemaVersion: z.number().int().min(1).default(1),
  serverId: z.string().max(32).default('main'),
  actor: z
    .object({
      accountId: z.number().int().nullish(),
      characterId: z.number().int().nullish(),
      sessionId: z.string().uuid().nullish(),
    })
    .nullish(),
  target: z
    .object({
      kind: z.string().max(32),
      id: z.string().max(128),
    })
    .nullish(),
  context: z
    .object({
      pos: z
        .object({ x: z.number(), y: z.number(), z: z.number() })
        .nullish(),
      instance: z.string().max(64).nullish(),
    })
    .nullish(),
  correlationId: z.string().uuid().nullish(),
  payload: z.record(z.unknown()).default({}),
});

export type EventEnvelope = z.infer<typeof EventEnvelopeSchema>;

export const IngestBatchSchema = z.object({
  events: z.array(EventEnvelopeSchema).min(1).max(500),
});

/** Kategorie = erster Namespace-Teil des Typs ('money.transfer' -> 'money'). */
export function categoryOf(type: string): string {
  return type.split('.', 1)[0];
}
