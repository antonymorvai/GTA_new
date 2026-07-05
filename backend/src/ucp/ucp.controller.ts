import { Controller, Get, Param, NotFoundException, Req, UseGuards, Inject } from '@nestjs/common';
import { Pool as PgPool } from 'pg';
import { AuthGuard, AuthedRequest } from '../auth/auth.guard';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import type { RowDataPacket } from 'mysql2';

/** UCP-API: Spieler sehen ausschließlich die EIGENEN Daten. */
@Controller('v1/ucp')
@UseGuards(AuthGuard)
export class UcpController {
  private readonly logstore = new PgPool({ connectionString: process.env.LOGSTORE_URL, max: 3 });

  constructor(@Inject(GAMEDB) private readonly db: GameDb) {}

  @Get('dashboard')
  async dashboard(@Req() req: AuthedRequest): Promise<unknown> {
    const [account] = await this.db.query<RowDataPacket[]>(
      'SELECT username, whitelist_status, totp_enabled, created_at, last_login_at FROM accounts WHERE id = ?',
      [req.account.id]);
    const [characters] = await this.db.query<RowDataPacket[]>(
      `SELECT c.id, c.slot, c.first_name, c.last_name, c.state, c.played_minutes,
              m.cash, m.bank, b.account_number
       FROM characters c
       LEFT JOIN character_money m ON m.character_id = c.id
       LEFT JOIN bank_details b ON b.character_id = c.id
       WHERE c.account_id = ? AND c.deleted_at IS NULL`, [req.account.id]);
    return { account: account[0], characters };
  }

  /** Eigene Charaktere: Skills, offene Bußgelder. */
  @Get('characters/:id')
  async character(@Req() req: AuthedRequest, @Param('id') id: string): Promise<unknown> {
    const [chars] = await this.db.query<RowDataPacket[]>(
      'SELECT id, first_name, last_name FROM characters WHERE id = ? AND account_id = ? AND deleted_at IS NULL',
      [Number(id), req.account.id]);
    if (chars.length === 0) throw new NotFoundException();

    const [skills] = await this.db.query<RowDataPacket[]>(
      'SELECT skill, xp, last_used_at FROM character_skills WHERE character_id = ?', [Number(id)]);
    const [fines] = await this.db.query<RowDataPacket[]>(
      `SELECT id, law_code, amount, status, created_at FROM fines
       WHERE character_id = ? ORDER BY created_at DESC LIMIT 50`, [Number(id)]);
    return { character: chars[0], skills, fines };
  }

  /** Kontoauszug: money.*-Events des eigenen Charakters aus dem Log-Store. */
  @Get('characters/:id/statement')
  async statement(@Req() req: AuthedRequest, @Param('id') id: string): Promise<unknown[]> {
    const [chars] = await this.db.query<RowDataPacket[]>(
      'SELECT id FROM characters WHERE id = ? AND account_id = ? AND deleted_at IS NULL',
      [Number(id), req.account.id]);
    if (chars.length === 0) throw new NotFoundException();

    const result = await this.logstore.query(
      `SELECT time, type, payload FROM events
       WHERE category = 'money'
         AND (actor_character = $1
              OR (target_kind = 'character' AND target_id = $2))
       ORDER BY time DESC LIMIT 100`,
      [Number(id), id]);
    return result.rows;
  }
}
