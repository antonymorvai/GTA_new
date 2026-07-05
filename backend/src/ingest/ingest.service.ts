import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { EventEnvelope } from '../common/event-envelope';
import { REDIS, STREAMS } from '../redis/redis.provider';

@Injectable()
export class IngestService {
  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  /** Events einzeln in den Stream schreiben (Pipeline = 1 Roundtrip). */
  async publish(events: EventEnvelope[]): Promise<void> {
    const pipeline = this.redis.pipeline();
    for (const event of events) {
      pipeline.xadd(STREAMS.events, '*', 'event', JSON.stringify(event));
    }
    await pipeline.exec();
  }
}
