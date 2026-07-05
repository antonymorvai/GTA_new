import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Pool as PgPool } from 'pg';
import { EventPublisherService } from '../events/event-publisher.service';

/**
 * Regelbasierte Anomalie-Erkennung auf dem Log-Store.
 * Funde landen in der Prüf-Queue (anomalies-Tabelle) und als anomaly.detected-
 * Event. Regeln laufen periodisch; Schwellwerte via Env (ACP-Tuning-Anbindung
 * der Schwellwerte folgt als Feinschliff).
 */
@Injectable()
export class AnomalyService implements OnModuleInit {
  private readonly logger = new Logger(AnomalyService.name);
  private readonly logstore = new PgPool({ connectionString: process.env.LOGSTORE_URL, max: 3 });

  constructor(private readonly events: EventPublisherService) {}

  onModuleInit(): void {
    const minutes = Number(process.env.ANOMALY_SCAN_MINUTES ?? 15);
    setInterval(() => void this.scan().catch((e) => this.logger.error(e.message)), minutes * 60000);
  }

  async scan(): Promise<number> {
    let found = 0;
    found += await this.ruleMoneyCreated();
    found += await this.ruleAdminGiveSpike();
    found += await this.ruleDrugVolume();
    found += await this.ruleTransferRing();
    if (found > 0) this.logger.warn(`${found} neue Anomalie(n) in der Prüf-Queue`);
    return found;
  }

  /** R4: Transfer-Ring — Geld pendelt zwischen zwei Charakteren hin und her
   *  (Geldwäsche-/Dupe-Indikator): A->B UND B->A jeweils über Schwellwert in 24 h. */
  private async ruleTransferRing(): Promise<number> {
    const threshold = Number(process.env.ANOMALY_RING_24H ?? 20000000); // 200k $ Cent
    const result = await this.logstore.query(
      `WITH pair_sums AS (
         SELECT payload->'from'->>'characterId' AS a,
                payload->'to'->>'characterId'   AS b,
                sum((payload->>'amount')::bigint) AS total
         FROM events
         WHERE type = 'money.transfer' AND time > now() - interval '24 hours'
           AND payload->'from'->>'characterId' IS NOT NULL
           AND payload->'to'->>'characterId' IS NOT NULL
         GROUP BY 1, 2
       )
       SELECT x.a, x.b, x.total AS ab_total, y.total AS ba_total
       FROM pair_sums x JOIN pair_sums y ON x.a = y.b AND x.b = y.a
       WHERE x.a < x.b AND x.total > $1 AND y.total > $1`,
      [threshold]);
    let n = 0;
    for (const row of result.rows) {
      n += await this.insert('transfer_ring', 'character', String(row.a),
        { partner: Number(row.b), abTotal: Number(row.ab_total),
          baTotal: Number(row.ba_total), threshold });
    }
    return n;
  }

  /** Dedup: gleiche Regel + Subjekt nur 1x pro 24h offen. */
  private async insert(rule: string, subjectKind: string, subjectId: string,
    detail: Record<string, unknown>): Promise<number> {
    const dupe = await this.logstore.query(
      `SELECT 1 FROM anomalies WHERE rule = $1 AND subject_kind = $2 AND subject_id = $3
       AND created_at > now() - interval '24 hours'`,
      [rule, subjectKind, subjectId]);
    if (dupe.rows.length > 0) return 0;

    await this.logstore.query(
      `INSERT INTO anomalies (rule, subject_kind, subject_id, detail) VALUES ($1, $2, $3, $4)`,
      [rule, subjectKind, subjectId, JSON.stringify(detail)]);
    await this.events.emit('anomaly.detected', {
      target: { kind: subjectKind, id: subjectId },
      payload: { rule, ...detail },
    });
    return 1;
  }

  /** R1: Ungewöhnlicher Geldzuwachs (money.create) pro Charakter in 24 h. */
  private async ruleMoneyCreated(): Promise<number> {
    const threshold = Number(process.env.ANOMALY_MONEY_CREATED_24H ?? 100000000); // 1 Mio $ in Cent
    const result = await this.logstore.query(
      `SELECT actor_character, sum((payload->>'amount')::bigint) AS total
       FROM events
       WHERE type = 'money.create' AND actor_character IS NOT NULL
         AND time > now() - interval '24 hours'
       GROUP BY actor_character HAVING sum((payload->>'amount')::bigint) > $1`,
      [threshold]);
    let n = 0;
    for (const row of result.rows) {
      n += await this.insert('money_created_24h', 'character', String(row.actor_character),
        { total: Number(row.total), threshold });
    }
    return n;
  }

  /** R2: Auffällig viele Admin-Vergaben durch denselben Admin in 24 h. */
  private async ruleAdminGiveSpike(): Promise<number> {
    const threshold = Number(process.env.ANOMALY_ADMIN_GIVES_24H ?? 20);
    const result = await this.logstore.query(
      `SELECT actor_account, count(*) AS cnt FROM events
       WHERE type = 'admin.action'
         AND payload->>'action' IN ('givemoney','giveitem')
         AND time > now() - interval '24 hours'
       GROUP BY actor_account HAVING count(*) > $1`,
      [threshold]);
    let n = 0;
    for (const row of result.rows) {
      n += await this.insert('admin_give_spike', 'account', String(row.actor_account),
        { count: Number(row.cnt), threshold });
    }
    return n;
  }

  /** R3: Drogenumsatz-Ausreißer (Geldwäsche-/Farm-Indikator). */
  private async ruleDrugVolume(): Promise<number> {
    const threshold = Number(process.env.ANOMALY_DRUG_SALES_24H ?? 50000000); // 500k $ Cent
    const result = await this.logstore.query(
      `SELECT actor_character, sum((payload->>'total')::bigint) AS total
       FROM events
       WHERE type = 'drug.sale' AND actor_character IS NOT NULL
         AND time > now() - interval '24 hours'
       GROUP BY actor_character HAVING sum((payload->>'total')::bigint) > $1`,
      [threshold]);
    let n = 0;
    for (const row of result.rows) {
      n += await this.insert('drug_volume_24h', 'character', String(row.actor_character),
        { total: Number(row.total), threshold });
    }
    return n;
  }

  async list(status?: string): Promise<unknown[]> {
    const result = await this.logstore.query(
      `SELECT id, created_at, rule, subject_kind, subject_id, detail, status, assigned_to, resolution
       FROM anomalies ${status ? 'WHERE status = $1' : ''} ORDER BY created_at DESC LIMIT 200`,
      status ? [status] : []);
    return result.rows;
  }

  async update(id: number, status: string, assignedTo: number | null, resolution: string | null): Promise<void> {
    await this.logstore.query(
      `UPDATE anomalies SET status = $2, assigned_to = $3, resolution = $4 WHERE id = $1`,
      [id, status, assignedTo, resolution]);
  }
}
