import {
  BadRequestException, Body, Controller, Get, Inject, NotFoundException,
  Param, Patch, Post, Query, Req, UseGuards,
} from '@nestjs/common';
import { AuthGuard, AuthedRequest, RequirePermission } from '../auth/auth.guard';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import { EventPublisherService } from '../events/event-publisher.service';
import type { RowDataPacket } from 'mysql2';

/**
 * ACP-Workflows: Whitelist-Review, Ticket-Bearbeitung, Sanktionen.
 * Jeder Lesezugriff -> admin.access; jede Entscheidung -> web.mutation
 * (bzw. security.ban bei Bans) mit Begründung.
 */
@Controller('v1/acp')
@UseGuards(AuthGuard)
export class AcpWorkflowController {
  constructor(
    @Inject(GAMEDB) private readonly db: GameDb,
    private readonly events: EventPublisherService,
  ) {}

  private access(req: AuthedRequest, view: string, extra: Record<string, unknown> = {}): void {
    void this.events.emit('admin.access', {
      actor: { accountId: req.account.id },
      payload: { view, ...extra },
    });
  }

  // --- Whitelist-Review ---

  @Get('applications')
  @RequirePermission('acp.whitelist.review')
  async applications(@Req() req: AuthedRequest, @Query('status') status?: string): Promise<unknown[]> {
    this.access(req, 'applications', { status });
    const filter = ['pending', 'approved', 'rejected'].includes(status ?? '') ? status : 'pending';
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT w.id, w.account_id, a.username, w.answers, w.test_score, w.test_total,
              w.status, w.review_note, w.created_at
       FROM whitelist_applications w JOIN accounts a ON a.id = w.account_id
       WHERE w.status = ? ORDER BY w.created_at ASC LIMIT 100`, [filter]);
    return rows;
  }

  @Post('applications/:id/decide')
  @RequirePermission('acp.whitelist.review')
  async decide(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { approve?: boolean; note?: string }): Promise<{ ok: true }> {
    const approve = body?.approve === true;
    const note = String(body?.note ?? '').trim();
    if (!approve && note.length < 5) {
      throw new BadRequestException('Bei Ablehnung ist eine Begründung Pflicht.');
    }

    const [apps] = await this.db.query<RowDataPacket[]>(
      `SELECT id, account_id FROM whitelist_applications WHERE id = ? AND status = 'pending'`,
      [Number(id)]);
    if (apps.length === 0) throw new NotFoundException('Bewerbung nicht gefunden oder bereits entschieden.');

    await this.db.query(
      `UPDATE whitelist_applications
       SET status = ?, reviewed_by = ?, review_note = ?, reviewed_at = NOW(3) WHERE id = ?`,
      [approve ? 'approved' : 'rejected', req.account.id, note || null, Number(id)]);
    await this.db.query(
      `UPDATE accounts SET whitelist_status = ? WHERE id = ?`,
      [approve ? 'approved' : 'rejected', apps[0].account_id]);

    await this.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      target: { kind: 'account', id: String(apps[0].account_id) },
      payload: { action: 'whitelist_decide', applicationId: Number(id), approve, note },
    });
    return { ok: true };
  }

  // --- Tickets ---

  @Get('tickets')
  @RequirePermission('acp.tickets.manage')
  async tickets(@Req() req: AuthedRequest, @Query('status') status?: string): Promise<unknown[]> {
    this.access(req, 'tickets', { status });
    const filter = ['open', 'answered', 'closed'].includes(status ?? '') ? status : 'open';
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT t.id, t.category, t.subject, t.reported_ref, t.status, t.created_at,
              a.username, a.id AS account_id
       FROM tickets t JOIN accounts a ON a.id = t.account_id
       WHERE t.status = ? ORDER BY t.created_at ASC LIMIT 100`, [filter]);
    return rows;
  }

  @Get('tickets/:id')
  @RequirePermission('acp.tickets.manage')
  async ticket(@Req() req: AuthedRequest, @Param('id') id: string): Promise<unknown> {
    this.access(req, 'ticket', { ticketId: Number(id) });
    const [tickets] = await this.db.query<RowDataPacket[]>(
      `SELECT t.*, a.username FROM tickets t JOIN accounts a ON a.id = t.account_id WHERE t.id = ?`,
      [Number(id)]);
    if (tickets.length === 0) throw new NotFoundException();
    const [messages] = await this.db.query<RowDataPacket[]>(
      `SELECT m.body, m.evidence, m.is_staff, m.created_at, a.username
       FROM ticket_messages m JOIN accounts a ON a.id = m.author_id
       WHERE m.ticket_id = ? ORDER BY m.created_at`, [Number(id)]);
    return { ticket: tickets[0], messages };
  }

  @Post('tickets/:id/reply')
  @RequirePermission('acp.tickets.manage')
  async reply(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { body?: string; close?: boolean }): Promise<{ ok: true }> {
    const text = String(body?.body ?? '').trim();
    if (text.length < 2) throw new BadRequestException('Antwort fehlt.');

    const [tickets] = await this.db.query<RowDataPacket[]>(
      `SELECT id FROM tickets WHERE id = ?`, [Number(id)]);
    if (tickets.length === 0) throw new NotFoundException();

    await this.db.query(
      `INSERT INTO ticket_messages (ticket_id, author_id, is_staff, body) VALUES (?, ?, 1, ?)`,
      [Number(id), req.account.id, text]);
    await this.db.query(
      `UPDATE tickets SET status = ?, assigned_to = ?, closed_at = ? WHERE id = ?`,
      [body?.close ? 'closed' : 'answered', req.account.id,
       body?.close ? new Date() : null, Number(id)]);

    await this.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      payload: { action: body?.close ? 'ticket_close' : 'ticket_reply', ticketId: Number(id) },
    });
    return { ok: true };
  }

  // --- Sanktionen (Begründung + Beweis Pflicht) ---

  @Post('sanctions')
  @RequirePermission('acp.sanctions.manage')
  async sanction(@Req() req: AuthedRequest, @Body() body: {
    accountId?: number; kind?: string; reason?: string; evidence?: string; hours?: number;
  }): Promise<{ ok: true; banId?: number }> {
    const accountId = Number(body?.accountId);
    const kind = String(body?.kind ?? '');
    const reason = String(body?.reason ?? '').trim();
    const evidence = String(body?.evidence ?? '').trim();

    if (!accountId || !['warn', 'ban'].includes(kind)) throw new BadRequestException('accountId/kind ungültig');
    if (reason.length < 10) throw new BadRequestException('Begründung ist Pflicht (min. 10 Zeichen).');
    if (evidence.length < 5) throw new BadRequestException('Beweis-Verweis ist Pflicht (Log-Permalink/Ticket).');

    const [accounts] = await this.db.query<RowDataPacket[]>(
      'SELECT id FROM accounts WHERE id = ?', [accountId]);
    if (accounts.length === 0) throw new NotFoundException('Account nicht gefunden');

    let banId: number | undefined;
    if (kind === 'ban') {
      const hours = Number(body?.hours ?? 0);
      const [result] = await this.db.query(
        `INSERT INTO account_bans (account_id, issued_by, reason, evidence, expires_at)
         VALUES (?, ?, ?, ?, IF(? = 0, NULL, DATE_ADD(NOW(3), INTERVAL ? HOUR)))`,
        [accountId, req.account.id, reason, evidence, hours, hours]);
      banId = (result as { insertId: number }).insertId;

      await this.events.emit('security.ban', {
        actor: { accountId: req.account.id },
        target: { kind: 'account', id: String(accountId) },
        payload: { banId, reason, evidence, hours, byAccountId: req.account.id, source: 'acp' },
      });
    }

    await this.db.query(
      `INSERT INTO sanctions (account_id, kind, reason, evidence, ban_id, issued_by) VALUES (?, ?, ?, ?, ?, ?)`,
      [accountId, kind, reason, evidence, banId ?? null, req.account.id]);

    await this.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      target: { kind: 'account', id: String(accountId) },
      payload: { action: 'sanction', kind, reason, banId },
    });
    return { ok: true, banId };
  }

  @Get('sanctions/:accountId')
  @RequirePermission('acp.sanctions.manage')
  async sanctionHistory(@Req() req: AuthedRequest, @Param('accountId') accountId: string): Promise<unknown[]> {
    this.access(req, 'sanction_history', { targetAccountId: Number(accountId) });
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT s.kind, s.reason, s.evidence, s.created_at, a.username AS issued_by_name
       FROM sanctions s JOIN accounts a ON a.id = s.issued_by
       WHERE s.account_id = ? ORDER BY s.created_at DESC`, [Number(accountId)]);
    return rows;
  }
}
