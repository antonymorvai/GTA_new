import { Controller, Get, Inject } from '@nestjs/common';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import type { RowDataPacket } from 'mysql2';

/** Öffentlicher Server-Status für die Homepage (bewusst datensparsam). */
@Controller('v1/public')
export class PublicController {
  private cache: { at: number; data: unknown } | null = null;

  constructor(@Inject(GAMEDB) private readonly db: GameDb) {}

  /** Zeitung: die letzten Artikel (öffentlich — Auflage = Reichweite). */
  @Get('news')
  async news(): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT a.id, a.headline, a.body, a.published_at, c.first_name, c.last_name
       FROM news_articles a JOIN characters c ON c.id = a.author_id
       ORDER BY a.published_at DESC LIMIT 20`);
    return rows;
  }

  @Get('status')
  async status(): Promise<unknown> {
    // 10-s-Cache: die Homepage darf die DB nicht fluten
    if (this.cache && Date.now() - this.cache.at < 10000) return this.cache.data;

    const [online] = await this.db.query<RowDataPacket[]>(
      `SELECT COUNT(*) AS n FROM sessions WHERE ended_at IS NULL AND started_at > DATE_SUB(NOW(3), INTERVAL 1 DAY)`);
    const [characters] = await this.db.query<RowDataPacket[]>(
      `SELECT COUNT(*) AS n FROM characters WHERE deleted_at IS NULL`);

    const data = {
      online: Number(online[0]?.n ?? 0),
      maxSlots: 128,
      charactersTotal: Number(characters[0]?.n ?? 0),
    };
    this.cache = { at: Date.now(), data };
    return data;
  }
}
