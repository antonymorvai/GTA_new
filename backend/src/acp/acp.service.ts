import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { Pool as PgPool } from 'pg';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import { EventPublisherService } from '../events/event-publisher.service';
import type { RowDataPacket } from 'mysql2';

export interface LogFilter {
  type?: string;
  category?: string;
  actorAccount?: number;
  actorCharacter?: number;
  targetKind?: string;
  targetId?: string;
  correlationId?: string;
  text?: string;
  from?: string;
  to?: string;
  limit: number;
  offset: number;
}

@Injectable()
export class AcpService {
  private readonly logstore = new PgPool({ connectionString: process.env.LOGSTORE_URL, max: 5 });

  constructor(
    @Inject(GAMEDB) private readonly db: GameDb,
    readonly events: EventPublisherService,
  ) {}

  // -------------------------------------------------------------------------
  // Log-Explorer (kombinierbare Filter, Permalink-fähig da rein Query-basiert)
  // -------------------------------------------------------------------------

  async queryLogs(filter: LogFilter): Promise<unknown[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    const add = (clause: string, value: unknown): void => {
      params.push(value);
      where.push(clause.replace('$?', `$${params.length}`));
    };

    if (filter.type) add('type LIKE $?', filter.type + '%');
    if (filter.category) add('category = $?', filter.category);
    if (filter.actorAccount) add('actor_account = $?', filter.actorAccount);
    if (filter.actorCharacter) add('actor_character = $?', filter.actorCharacter);
    if (filter.targetKind) add('target_kind = $?', filter.targetKind);
    if (filter.targetId) add('target_id = $?', filter.targetId);
    if (filter.correlationId) add('correlation_id = $?', filter.correlationId);
    if (filter.text) add('payload::text ILIKE $?', `%${filter.text}%`);
    if (filter.from) add('time >= $?', new Date(filter.from));
    if (filter.to) add('time <= $?', new Date(filter.to));

    params.push(Math.min(filter.limit, 500), filter.offset);
    const sql = `
      SELECT time, event_id, type, category, actor_account, actor_character,
             session_id, target_kind, target_id, correlation_id,
             pos_x, pos_y, pos_z, payload
      FROM events
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY time DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await this.logstore.query(sql, params);
    return result.rows;
  }

  // -------------------------------------------------------------------------
  // Universal-Timeline: alles, was eine Entität betrifft (Akteur ODER Ziel)
  // -------------------------------------------------------------------------

  async timeline(kind: 'character' | 'account' | 'item' | 'vehicle' | 'company' | 'property',
    id: string, limit: number, offset: number): Promise<unknown[]> {
    const clauses: Record<string, string> = {
      character: '(actor_character = $1::bigint OR (target_kind = \'character\' AND target_id = $1))',
      account: '(actor_account = $1::bigint OR (target_kind = \'account\' AND target_id = $1))',
      item: "(target_kind = 'item' AND target_id = $1)",
      vehicle: "(target_kind = 'vehicle' AND target_id = $1)",
      company: "(target_kind = 'company' AND target_id = $1)",
      property: "(target_kind = 'property' AND target_id = $1)",
    };
    const result = await this.logstore.query(
      `SELECT time, event_id, type, category, actor_account, actor_character,
              target_kind, target_id, correlation_id, payload
       FROM events WHERE ${clauses[kind]}
       ORDER BY time DESC LIMIT $2 OFFSET $3`,
      [id, Math.min(limit, 500), offset],
    );
    return result.rows;
  }

  /** Alle Events einer Korrelation (eine Transaktion als Ganzes). */
  async correlation(correlationId: string): Promise<unknown[]> {
    const result = await this.logstore.query(
      'SELECT * FROM events WHERE correlation_id = $1 ORDER BY time ASC',
      [correlationId],
    );
    return result.rows;
  }

  // -------------------------------------------------------------------------
  // Geldfluss-Graph: aggregierte Kanten um einen Charakter (n Hops iterativ)
  // -------------------------------------------------------------------------

  async moneyFlow(characterId: number, days: number, hops: number): Promise<{
    nodes: Array<{ id: string; kind: string }>;
    edges: Array<{ from: string; to: string; total: number; count: number }>;
  }> {
    const frontier = new Set<string>([String(characterId)]);
    const visited = new Set<string>();
    const edges = new Map<string, { from: string; to: string; total: number; count: number }>();

    for (let hop = 0; hop < Math.min(hops, 4); hop++) {
      const ids = [...frontier].filter((id) => !visited.has(id));
      if (ids.length === 0) break;
      ids.forEach((id) => visited.add(id));
      frontier.clear();

      const result = await this.logstore.query(
        `SELECT payload->'from'->>'characterId' AS from_id,
                COALESCE(payload->'to'->>'characterId', payload->'to'->>'companyId') AS to_id,
                (payload->'to'->>'companyId') IS NOT NULL AS to_company,
                sum((payload->>'amount')::bigint) AS total, count(*) AS cnt
         FROM events
         WHERE type = 'money.transfer' AND time > now() - ($2 || ' days')::interval
           AND (payload->'from'->>'characterId' = ANY($1)
                OR payload->'to'->>'characterId' = ANY($1))
         GROUP BY 1, 2, 3`,
        [ids, String(Math.min(days, 90))],
      );

      for (const row of result.rows) {
        const from = row.from_id ?? 'system';
        const to = (row.to_company ? 'company:' : '') + (row.to_id ?? 'system');
        const key = `${from}->${to}`;
        const existing = edges.get(key) ?? { from, to, total: 0, count: 0 };
        existing.total += Number(row.total);
        existing.count += Number(row.cnt);
        edges.set(key, existing);
        if (!row.to_company && row.to_id) frontier.add(row.to_id);
        if (row.from_id) frontier.add(row.from_id);
      }
    }

    const nodes = new Set<string>();
    for (const e of edges.values()) {
      nodes.add(e.from);
      nodes.add(e.to);
    }
    return {
      nodes: [...nodes].map((id) => ({
        id,
        kind: id.startsWith('company:') ? 'company' : id === 'system' ? 'system' : 'character',
      })),
      edges: [...edges.values()],
    };
  }

  // -------------------------------------------------------------------------
  // Session-Replay: Bewegungsdaten eines Zeitfensters
  // -------------------------------------------------------------------------

  async replay(characterId: number, from: string, to: string): Promise<unknown[]> {
    const result = await this.logstore.query(
      `SELECT time, x, y, z, heading, speed FROM position_samples
       WHERE character_id = $1 AND time BETWEEN $2 AND $3
       ORDER BY time ASC LIMIT 10000`,
      [characterId, new Date(from), new Date(to)],
    );
    return result.rows;
  }

  // -------------------------------------------------------------------------
  // 360°-Spielerakte (Spiel-DB)
  // -------------------------------------------------------------------------

  async searchPlayers(query: string): Promise<unknown[]> {
    const like = `%${query}%`;
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT a.id AS account_id, a.username, a.whitelist_status, a.last_login_at,
              c.id AS character_id, c.first_name, c.last_name
       FROM accounts a
       LEFT JOIN characters c ON c.account_id = a.id AND c.deleted_at IS NULL
       WHERE a.username LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ?
       LIMIT 50`,
      [like, like, like],
    );
    return rows;
  }

  async playerFile(accountId: number): Promise<Record<string, unknown>> {
    const [accounts] = await this.db.query<RowDataPacket[]>(
      `SELECT id, username, email, whitelist_status, totp_enabled, created_at, last_login_at
       FROM accounts WHERE id = ?`, [accountId]);
    if (accounts.length === 0) throw new NotFoundException('Account nicht gefunden');

    const [characters] = await this.db.query<RowDataPacket[]>(
      `SELECT c.id, c.slot, c.first_name, c.last_name, c.state, c.played_minutes,
              m.cash, m.bank
       FROM characters c LEFT JOIN character_money m ON m.character_id = c.id
       WHERE c.account_id = ? AND c.deleted_at IS NULL`, [accountId]);
    const [identifiers] = await this.db.query<RowDataPacket[]>(
      'SELECT id_type, id_value, first_seen, last_seen FROM account_identifiers WHERE account_id = ?',
      [accountId]);
    const [bans] = await this.db.query<RowDataPacket[]>(
      'SELECT id, reason, expires_at, created_at, revoked_at FROM account_bans WHERE account_id = ? ORDER BY created_at DESC',
      [accountId]);
    const [roles] = await this.db.query<RowDataPacket[]>(
      `SELECT r.name FROM account_roles ar JOIN roles r ON r.id = ar.role_id WHERE ar.account_id = ?`,
      [accountId]);

    const characterIds = characters.map((c) => c.id);
    let vehicles: RowDataPacket[] = [];
    let properties: RowDataPacket[] = [];
    let fines: RowDataPacket[] = [];
    if (characterIds.length > 0) {
      [vehicles] = await this.db.query<RowDataPacket[]>(
        `SELECT v.plate, m.label, v.stored, v.mileage_km FROM vehicles v
         JOIN vehicle_models m ON m.id = v.model_id
         WHERE v.owner_id IN (?) AND v.deleted_at IS NULL`, [characterIds]);
      [properties] = await this.db.query<RowDataPacket[]>(
        'SELECT id, label, prop_type, region FROM properties WHERE owner_id IN (?)', [characterIds]);
      [fines] = await this.db.query<RowDataPacket[]>(
        `SELECT id, character_id, law_code, amount, status, created_at FROM fines
         WHERE character_id IN (?) ORDER BY created_at DESC LIMIT 20`, [characterIds]);
    }

    return {
      account: accounts[0], roles: roles.map((r) => r.name), characters,
      identifiers, bans, vehicles, properties, fines,
    };
  }

  // -------------------------------------------------------------------------
  // Live-Tuning (schreibt Spiel-DB; Gameserver pollt den Stand periodisch)
  // -------------------------------------------------------------------------

  async listTuning(): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      'SELECT flag_key, flag_value, description, updated_by, updated_at FROM config_flags ORDER BY flag_key');
    return rows;
  }

  async setTuning(key: string, value: unknown, byAccountId: number): Promise<void> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      'SELECT flag_value FROM config_flags WHERE flag_key = ?', [key]);
    const before = rows[0] ? JSON.parse(rows[0].flag_value) : null;

    await this.db.query(
      `INSERT INTO config_flags (flag_key, flag_value, updated_by) VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE flag_value = VALUES(flag_value), updated_by = VALUES(updated_by)`,
      [key, JSON.stringify(value), byAccountId]);
    await this.db.query(
      'INSERT INTO config_flag_history (flag_key, old_value, new_value, changed_by) VALUES (?, ?, ?, ?)',
      [key, before !== null ? JSON.stringify(before) : null, JSON.stringify(value), byAccountId]);

    await this.events.emit('config.change', {
      actor: { accountId: byAccountId },
      target: { kind: 'config_flag', id: key },
      payload: { key, before, after: value, source: 'acp' },
    });
  }

  async tuningHistory(key: string): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      'SELECT old_value, new_value, changed_by, changed_at FROM config_flag_history WHERE flag_key = ? ORDER BY changed_at DESC LIMIT 50',
      [key]);
    return rows;
  }
}
