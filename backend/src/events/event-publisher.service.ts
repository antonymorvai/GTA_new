import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { randomUUID } from 'crypto';
import { REDIS, STREAMS } from '../redis/redis.provider';
import { EventEnvelope } from '../common/event-envelope';

/**
 * Publiziert Web-/Backend-Events in denselben Stream wie der Gameserver —
 * eine Pipeline, ein Katalog, ein Log-Store (web.login, web.mutation,
 * admin.access, config.change, anomaly.*).
 */
@Injectable()
export class EventPublisherService {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  async emit(
    type: string,
    data: {
      actor?: { accountId?: number | null; characterId?: number | null };
      target?: { kind: string; id: string };
      correlationId?: string;
      payload?: Record<string, unknown>;
    },
  ): Promise<void> {
    const envelope: EventEnvelope = {
      eventId: randomUUID(),
      ts: Date.now(),
      type,
      schemaVersion: 1,
      serverId: 'web',
      actor: data.actor ?? null,
      target: data.target ?? null,
      context: null,
      correlationId: data.correlationId ?? null,
      payload: data.payload ?? {},
    };
    await this.redis.xadd(STREAMS.events, '*', 'event', JSON.stringify(envelope));
  }
}
