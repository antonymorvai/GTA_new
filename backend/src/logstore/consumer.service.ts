import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import type Redis from 'ioredis';
import { EventEnvelope, EventEnvelopeSchema } from '../common/event-envelope';
import { REDIS, STREAMS } from '../redis/redis.provider';
import { LogstoreWriter } from './logstore.writer';
import { AlertService } from './alert.service';

type StreamEntry = [id: string, fields: string[]];

/**
 * Redis-Stream-Consumer (Consumer-Group => At-least-once):
 * XREADGROUP -> Batch-INSERT -> XACK. Fehlerhafte/unparsbare Events wandern
 * in den Dead-Letter-Stream statt die Pipeline zu blockieren.
 */
@Injectable()
export class ConsumerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ConsumerService.name);
  private running = true;
  private readonly consumerName = `consumer-${process.pid}`;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    private readonly writer: LogstoreWriter,
    private readonly alerts: AlertService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.ensureGroup();
    void this.loop();
  }

  onModuleDestroy(): void {
    this.running = false;
  }

  private async ensureGroup(): Promise<void> {
    try {
      await this.redis.xgroup('CREATE', STREAMS.events, STREAMS.group, '0', 'MKSTREAM');
    } catch (err) {
      if (!String(err).includes('BUSYGROUP')) throw err;
    }
  }

  private async loop(): Promise<void> {
    // Blockierendes Lesen braucht eine eigene Verbindung
    const reader = this.redis.duplicate();
    while (this.running) {
      try {
        const result = (await reader.xreadgroup(
          'GROUP', STREAMS.group, this.consumerName,
          'COUNT', 500,
          'BLOCK', 5000,
          'STREAMS', STREAMS.events, '>',
        )) as Array<[string, StreamEntry[]]> | null;

        if (!result || result.length === 0) continue;
        const entries = result[0][1];
        if (entries.length === 0) continue;

        await this.process(entries);
      } catch (err) {
        this.logger.error(`Consumer-Fehler: ${(err as Error).message}`);
        await new Promise((r) => setTimeout(r, 2000));
      }
    }
    reader.disconnect();
  }

  private async process(entries: StreamEntry[]): Promise<void> {
    const valid: EventEnvelope[] = [];
    const validIds: string[] = [];
    const dead: Array<{ id: string; raw: string; error: string }> = [];

    for (const [id, fields] of entries) {
      const raw = this.fieldValue(fields, 'event');
      if (!raw) {
        dead.push({ id, raw: '', error: 'missing_event_field' });
        continue;
      }
      try {
        const parsed = EventEnvelopeSchema.parse(JSON.parse(raw));
        valid.push(parsed);
        validIds.push(id);
      } catch (err) {
        dead.push({ id, raw, error: String(err).slice(0, 500) });
      }
    }

    if (valid.length > 0) {
      // Insert-Fehler: NICHT ack'en -> Redelivery (at-least-once, Log-Verlust
      // ist schlimmer als Duplikate; event_id erlaubt Dedup in Auswertungen).
      await this.writer.writeBatch(valid);
      await this.redis.xack(STREAMS.events, STREAMS.group, ...validIds);
      // Alerts NACH erfolgreichem Persistieren (nie blockierend für die Pipeline)
      void this.alerts.checkBatch(valid);
    }

    if (dead.length > 0) {
      const pipeline = this.redis.pipeline();
      for (const d of dead) {
        pipeline.xadd(STREAMS.dead, '*', 'raw', d.raw, 'error', d.error);
        pipeline.xack(STREAMS.events, STREAMS.group, d.id);
      }
      await pipeline.exec();
      this.logger.warn(`${dead.length} Events in Dead-Letter verschoben`);
    }
  }

  private fieldValue(fields: string[], key: string): string | undefined {
    for (let i = 0; i < fields.length - 1; i += 2) {
      if (fields[i] === key) return fields[i + 1];
    }
    return undefined;
  }
}
