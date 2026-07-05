import {
  BadRequestException, Body, Controller, Get, Inject, NotFoundException,
  Param, Post, Req, UseGuards,
} from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, AuthedRequest } from '../auth/auth.guard';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import { EventPublisherService } from '../events/event-publisher.service';
import { PASS_SCORE, RULE_QUESTIONS } from './whitelist';
import type { RowDataPacket } from 'mysql2';

const ApplySchema = z.object({
  answers: z.record(z.number().int().min(0).max(3)),
  characterConcept: z.string().min(300).max(5000),
  age: z.number().int().min(16).max(99),
  rpExperience: z.string().min(10).max(2000),
});

const TicketSchema = z.object({
  category: z.enum(['support', 'bug', 'complaint', 'report', 'refund', 'other']),
  subject: z.string().min(5).max(200),
  body: z.string().min(20).max(5000),
  reportedRef: z.string().max(128).optional(),
  evidence: z.string().max(1000).optional(),
});

/** UCP-Workflows: Whitelist-Bewerbung mit Regeltest, Tickets & Reports. */
@Controller('v1/ucp')
@UseGuards(AuthGuard)
export class UcpWorkflowController {
  constructor(
    @Inject(GAMEDB) private readonly db: GameDb,
    private readonly events: EventPublisherService,
  ) {}

  // --- Whitelist ---

  @Get('whitelist/questions')
  questions(): Array<{ id: string; question: string; options: string[] }> {
    // correct-Index wird bewusst NICHT mitgesendet
    return RULE_QUESTIONS.map(({ id, question, options }) => ({ id, question, options }));
  }

  @Get('whitelist/status')
  async whitelistStatus(@Req() req: AuthedRequest): Promise<unknown> {
    const [apps] = await this.db.query<RowDataPacket[]>(
      `SELECT id, status, test_score, test_total, review_note, created_at, reviewed_at
       FROM whitelist_applications WHERE account_id = ? ORDER BY created_at DESC LIMIT 5`,
      [req.account.id]);
    return apps;
  }

  @Post('whitelist/apply')
  async apply(@Req() req: AuthedRequest, @Body() body: unknown): Promise<{ score: number; total: number }> {
    const parsed = ApplySchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.issues[0]?.message ?? 'Ungültige Bewerbung');
    }

    // Bereits offene/angenommene Bewerbung?
    const [existing] = await this.db.query<RowDataPacket[]>(
      `SELECT status FROM whitelist_applications
       WHERE account_id = ? AND status IN ('pending','approved') LIMIT 1`, [req.account.id]);
    if (existing.length > 0) {
      throw new BadRequestException(
        existing[0].status === 'approved'
          ? 'Du bist bereits freigeschaltet.'
          : 'Deine Bewerbung ist bereits in Prüfung.');
    }

    // Regeltest server-seitig bewerten
    let score = 0;
    for (const q of RULE_QUESTIONS) {
      if (parsed.data.answers[q.id] === q.correct) score++;
    }
    if (score < PASS_SCORE) {
      throw new BadRequestException(
        `Regeltest nicht bestanden (${score}/${RULE_QUESTIONS.length}, nötig: ${PASS_SCORE}). Lies das Regelwerk und versuche es erneut.`);
    }

    await this.db.query(
      `INSERT INTO whitelist_applications (account_id, answers, test_score, test_total) VALUES (?, ?, ?, ?)`,
      [req.account.id, JSON.stringify({
        characterConcept: parsed.data.characterConcept,
        age: parsed.data.age,
        rpExperience: parsed.data.rpExperience,
      }), score, RULE_QUESTIONS.length]);
    await this.db.query(
      `UPDATE accounts SET whitelist_status = 'pending' WHERE id = ? AND whitelist_status IN ('none','rejected')`,
      [req.account.id]);

    await this.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      payload: { action: 'whitelist_apply', score, total: RULE_QUESTIONS.length },
    });
    return { score, total: RULE_QUESTIONS.length };
  }

  // --- Tickets & Reports ---

  @Get('tickets')
  async myTickets(@Req() req: AuthedRequest): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT id, category, subject, status, created_at FROM tickets
       WHERE account_id = ? ORDER BY created_at DESC LIMIT 50`, [req.account.id]);
    return rows;
  }

  @Post('tickets')
  async createTicket(@Req() req: AuthedRequest, @Body() body: unknown): Promise<{ id: number }> {
    const parsed = TicketSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException(parsed.error.issues[0]?.message ?? 'Ungültiges Ticket');
    }
    if (parsed.data.category === 'report' && !parsed.data.reportedRef) {
      throw new BadRequestException('Bei Reports ist die Angabe des gemeldeten Spielers Pflicht.');
    }

    const [result] = await this.db.query(
      `INSERT INTO tickets (account_id, category, subject, reported_ref) VALUES (?, ?, ?, ?)`,
      [req.account.id, parsed.data.category, parsed.data.subject, parsed.data.reportedRef ?? null]);
    const ticketId = (result as { insertId: number }).insertId;

    await this.db.query(
      `INSERT INTO ticket_messages (ticket_id, author_id, is_staff, body, evidence) VALUES (?, ?, 0, ?, ?)`,
      [ticketId, req.account.id, parsed.data.body, parsed.data.evidence ?? null]);

    await this.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      payload: { action: 'ticket_create', ticketId, category: parsed.data.category },
    });
    return { id: ticketId };
  }

  @Get('tickets/:id')
  async ticket(@Req() req: AuthedRequest, @Param('id') id: string): Promise<unknown> {
    const [tickets] = await this.db.query<RowDataPacket[]>(
      `SELECT id, category, subject, reported_ref, status, created_at FROM tickets
       WHERE id = ? AND account_id = ?`, [Number(id), req.account.id]);
    if (tickets.length === 0) throw new NotFoundException();
    const [messages] = await this.db.query<RowDataPacket[]>(
      `SELECT m.body, m.evidence, m.is_staff, m.created_at, a.username
       FROM ticket_messages m JOIN accounts a ON a.id = m.author_id
       WHERE m.ticket_id = ? ORDER BY m.created_at`, [Number(id)]);
    return { ticket: tickets[0], messages };
  }

  @Post('tickets/:id/messages')
  async replyTicket(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { body?: string }): Promise<{ ok: true }> {
    const text = String(body?.body ?? '').trim();
    if (text.length < 2 || text.length > 5000) throw new BadRequestException('Nachricht: 2–5000 Zeichen');

    const [tickets] = await this.db.query<RowDataPacket[]>(
      `SELECT id, status FROM tickets WHERE id = ? AND account_id = ?`, [Number(id), req.account.id]);
    if (tickets.length === 0) throw new NotFoundException();
    if (tickets[0].status === 'closed') throw new BadRequestException('Ticket ist geschlossen.');

    await this.db.query(
      `INSERT INTO ticket_messages (ticket_id, author_id, is_staff, body) VALUES (?, ?, 0, ?)`,
      [Number(id), req.account.id, text]);
    await this.db.query(`UPDATE tickets SET status = 'open' WHERE id = ?`, [Number(id)]);
    return { ok: true };
  }

  // --- Eigene Sanktionen (Transparenz) ---

  @Get('sanctions')
  async mySanctions(@Req() req: AuthedRequest): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT kind, reason, created_at FROM sanctions
       WHERE account_id = ? ORDER BY created_at DESC LIMIT 50`, [req.account.id]);
    return rows;
  }
}
