import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Pool } from 'pg';
import { categoryOf, EventEnvelope } from '../common/event-envelope';

interface PositionSample {
  characterId: number;
  sessionId?: string | null;
  x: number;
  y: number;
  z: number;
  heading?: number;
  speed?: number;
}

/**
 * Schreibt validierte Events per Batch-INSERT in TimescaleDB.
 * position.batch-Events werden in position_samples entrollt, alles andere
 * landet in events. Append-only: dieser Writer kennt kein UPDATE/DELETE.
 */
@Injectable()
export class LogstoreWriter implements OnModuleInit {
  private readonly logger = new Logger(LogstoreWriter.name);
  private readonly pool = new Pool({
    connectionString: process.env.LOGSTORE_URL,
    max: 5,
  });

  async onModuleInit(): Promise<void> {
    await this.applyRetentionPolicies();
  }

  /** Retention gemäß Env (DSGVO-Konzept, konfigurierbar, 0 = nie löschen). */
  private async applyRetentionPolicies(): Promise<void> {
    const eventDays = Number(process.env.LOG_RETENTION_DAYS ?? 90);
    const posDays = Number(process.env.POSITION_RETENTION_DAYS ?? 30);
    try {
      if (eventDays > 0) {
        await this.pool.query(
          `SELECT add_retention_policy('events', INTERVAL '${eventDays} days', if_not_exists => TRUE)`,
        );
      }
      if (posDays > 0) {
        await this.pool.query(
          `SELECT add_retention_policy('position_samples', INTERVAL '${posDays} days', if_not_exists => TRUE)`,
        );
      }
      this.logger.log(`Retention: events=${eventDays}d, positions=${posDays}d`);
    } catch (err) {
      this.logger.warn(`Retention-Policies nicht gesetzt: ${(err as Error).message}`);
    }
  }

  async writeBatch(events: EventEnvelope[]): Promise<void> {
    const regular: EventEnvelope[] = [];
    const positions: Array<{ ts: number; sample: PositionSample }> = [];

    for (const event of events) {
      if (event.type === 'position.batch') {
        const samples = (event.payload as { samples?: PositionSample[] }).samples ?? [];
        for (const sample of samples) {
          if (typeof sample?.characterId === 'number') {
            positions.push({ ts: event.ts, sample });
          }
        }
      } else {
        regular.push(event);
      }
    }

    if (regular.length > 0) await this.insertEvents(regular);
    if (positions.length > 0) await this.insertPositions(positions);
  }

  private async insertEvents(events: EventEnvelope[]): Promise<void> {
    const cols = 16;
    const values: unknown[] = [];
    const rows = events.map((e, i) => {
      const base = i * cols;
      values.push(
        new Date(e.ts),
        e.eventId,
        e.type,
        categoryOf(e.type),
        e.schemaVersion,
        e.serverId,
        e.actor?.accountId ?? null,
        e.actor?.characterId ?? null,
        e.actor?.sessionId ?? null,
        e.target?.kind ?? null,
        e.target?.id ?? null,
        e.correlationId ?? null,
        e.context?.pos?.x ?? null,
        e.context?.pos?.y ?? null,
        e.context?.pos?.z ?? null,
        JSON.stringify(e.payload ?? {}),
      );
      const params = Array.from({ length: cols }, (_, c) => `$${base + c + 1}`);
      return `(${params.join(',')})`;
    });

    await this.pool.query(
      `INSERT INTO events (time, event_id, type, category, schema_version, server_id,
                           actor_account, actor_character, session_id,
                           target_kind, target_id, correlation_id,
                           pos_x, pos_y, pos_z, payload)
       VALUES ${rows.join(',')}`,
      values,
    );
  }

  private async insertPositions(entries: Array<{ ts: number; sample: PositionSample }>): Promise<void> {
    const cols = 8;
    const values: unknown[] = [];
    const rows = entries.map(({ ts, sample }, i) => {
      const base = i * cols;
      values.push(
        new Date(ts),
        sample.characterId,
        sample.sessionId ?? null,
        sample.x,
        sample.y,
        sample.z,
        sample.heading ?? 0,
        sample.speed ?? 0,
      );
      const params = Array.from({ length: cols }, (_, c) => `$${base + c + 1}`);
      return `(${params.join(',')})`;
    });

    await this.pool.query(
      `INSERT INTO position_samples (time, character_id, session_id, x, y, z, heading, speed)
       VALUES ${rows.join(',')}`,
      values,
    );
  }
}
