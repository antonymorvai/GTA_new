import {
  BadRequestException,
  Body, Controller, Get, Param, Patch, Post, Put, Query, Req, UseGuards,
} from '@nestjs/common';
import { AuthGuard, AuthedRequest, RequirePermission } from '../auth/auth.guard';
import { AcpService } from './acp.service';
import { AnomalyService } from './anomaly.service';

/**
 * ACP-API. JEDER Lesezugriff auf sensible Daten erzeugt ein admin.access-Event
 * (Access-Log, Katalog §admin) — auch das reine Anschauen.
 */
@Controller('v1/acp')
@UseGuards(AuthGuard)
export class AcpController {
  constructor(
    private readonly acp: AcpService,
    private readonly anomalies: AnomalyService,
  ) {}

  private access(req: AuthedRequest, view: string, extra: Record<string, unknown> = {}): void {
    void this.acp.events.emit('admin.access', {
      actor: { accountId: req.account.id },
      payload: { view, ...extra },
    });
  }

  // --- Aktivitäts-Heatmap ---
  @Get('heatmap')
  @RequirePermission('acp.logs.view')
  async heatmap(@Req() req: AuthedRequest, @Query('hours') hours?: string): Promise<unknown[]> {
    this.access(req, 'heatmap', { hours });
    return this.acp.heatmap(Number(hours ?? 24));
  }

  // --- Log-Explorer (format=csv für Export) ---
  @Get('logs')
  @RequirePermission('acp.logs.view')
  async logs(@Req() req: AuthedRequest, @Query() q: Record<string, string>): Promise<unknown> {
    this.access(req, 'logs', { filters: q });
    const rows = (await this.acp.queryLogs({
      type: q.type, category: q.category,
      actorAccount: q.actorAccount ? Number(q.actorAccount) : undefined,
      actorCharacter: q.actorCharacter ? Number(q.actorCharacter) : undefined,
      targetKind: q.targetKind, targetId: q.targetId,
      correlationId: q.correlationId, text: q.text,
      from: q.from, to: q.to,
      limit: Number(q.limit ?? 100), offset: Number(q.offset ?? 0),
    })) as Array<Record<string, unknown>>;

    if (q.format === 'csv') {
      const header = 'time;type;actor_account;actor_character;target_kind;target_id;correlation_id;payload';
      const lines = rows.map((r) =>
        [r.time, r.type, r.actor_account ?? '', r.actor_character ?? '',
         r.target_kind ?? '', r.target_id ?? '', r.correlation_id ?? '',
         JSON.stringify(r.payload).replace(/;/g, ',')].join(';'));
      return [header, ...lines].join('\n');
    }
    return rows;
  }

  // --- Universal-Timeline ---
  @Get('timeline/:kind/:id')
  @RequirePermission('acp.logs.view')
  async timeline(@Req() req: AuthedRequest, @Param('kind') kind: string, @Param('id') id: string,
    @Query('limit') limit?: string, @Query('offset') offset?: string): Promise<unknown[]> {
    const valid = ['character', 'account', 'item', 'vehicle', 'company', 'property'];
    if (!valid.includes(kind)) throw new BadRequestException('Ungültige Entität');
    this.access(req, 'timeline', { kind, id });
    return this.acp.timeline(kind as never, id, Number(limit ?? 100), Number(offset ?? 0));
  }

  @Get('correlation/:id')
  @RequirePermission('acp.logs.view')
  async correlation(@Req() req: AuthedRequest, @Param('id') id: string): Promise<unknown[]> {
    this.access(req, 'correlation', { correlationId: id });
    return this.acp.correlation(id);
  }

  // --- Geldfluss-Graph ---
  @Get('moneyflow/:characterId')
  @RequirePermission('acp.logs.view')
  async moneyFlow(@Req() req: AuthedRequest, @Param('characterId') characterId: string,
    @Query('days') days?: string, @Query('hops') hops?: string): Promise<unknown> {
    this.access(req, 'moneyflow', { characterId });
    return this.acp.moneyFlow(Number(characterId), Number(days ?? 7), Number(hops ?? 2));
  }

  // --- Item-Trace ---
  @Get('itemtrace/:uuid')
  @RequirePermission('acp.logs.view')
  async itemTrace(@Req() req: AuthedRequest, @Param('uuid') uuid: string): Promise<unknown[]> {
    this.access(req, 'itemtrace', { itemUuid: uuid });
    return this.acp.timeline('item', uuid, 500, 0);
  }

  // --- Session-Replay (Bewegungsdaten) ---
  @Get('replay/:characterId')
  @RequirePermission('acp.logs.view')
  async replay(@Req() req: AuthedRequest, @Param('characterId') characterId: string,
    @Query('from') from: string, @Query('to') to: string): Promise<unknown[]> {
    if (!from || !to) throw new BadRequestException('from/to (ISO) erforderlich');
    this.access(req, 'replay', { characterId, from, to });
    return this.acp.replay(Number(characterId), from, to);
  }

  // --- Kill-Akte ---
  @Get('killfile/:characterId')
  @RequirePermission('acp.logs.view')
  async killFile(@Req() req: AuthedRequest, @Param('characterId') characterId: string,
    @Query('at') at: string): Promise<unknown> {
    if (!at) throw new BadRequestException('at (ISO-Zeitpunkt des Downs) erforderlich');
    this.access(req, 'killfile', { characterId, at });
    return this.acp.killFile(Number(characterId), at);
  }

  // --- Live-Karte ---
  @Get('livemap')
  @RequirePermission('acp.player.view')
  async liveMap(@Req() req: AuthedRequest): Promise<unknown[]> {
    this.access(req, 'livemap');
    return this.acp.liveMap();
  }

  // --- Spielerverwaltung ---
  @Get('players')
  @RequirePermission('acp.player.view')
  async search(@Req() req: AuthedRequest, @Query('q') q: string): Promise<unknown[]> {
    if (!q || q.length < 2) throw new BadRequestException('Suchbegriff zu kurz');
    this.access(req, 'player_search', { query: q });
    return this.acp.searchPlayers(q);
  }

  @Get('players/:accountId')
  @RequirePermission('acp.player.view')
  async playerFile(@Req() req: AuthedRequest, @Param('accountId') accountId: string): Promise<unknown> {
    this.access(req, 'player_file', { targetAccountId: Number(accountId) });
    return this.acp.playerFile(Number(accountId));
  }

  // --- Wirtschafts-Dashboard ---
  @Get('economy')
  @RequirePermission('acp.logs.view')
  async economy(@Req() req: AuthedRequest): Promise<unknown> {
    this.access(req, 'economy');
    return this.acp.economyDashboard();
  }

  // --- Live-Tuning ---
  @Get('tuning')
  @RequirePermission('acp.tuning.edit')
  async tuning(@Req() req: AuthedRequest): Promise<unknown[]> {
    this.access(req, 'tuning');
    return this.acp.listTuning();
  }

  @Put('tuning/:key')
  @RequirePermission('acp.tuning.edit')
  async setTuning(@Req() req: AuthedRequest, @Param('key') key: string,
    @Body() body: { value?: unknown }): Promise<{ ok: true }> {
    if (!/^[\w.]{3,96}$/.test(key)) throw new BadRequestException('Ungültiger Key');
    if (body?.value === undefined) throw new BadRequestException('value fehlt');
    await this.acp.setTuning(key, body.value, req.account.id);
    return { ok: true };
  }

  @Get('tuning/:key/history')
  @RequirePermission('acp.tuning.edit')
  async tuningHistory(@Req() req: AuthedRequest, @Param('key') key: string): Promise<unknown[]> {
    return this.acp.tuningHistory(key);
  }

  // --- Anomalie-Queue ---
  @Get('anomalies')
  @RequirePermission('acp.logs.view')
  async listAnomalies(@Req() req: AuthedRequest, @Query('status') status?: string): Promise<unknown[]> {
    this.access(req, 'anomalies', { status });
    return this.anomalies.list(status);
  }

  @Post('anomalies/scan')
  @RequirePermission('acp.logs.view')
  async scan(): Promise<{ found: number }> {
    return { found: await this.anomalies.scan() };
  }

  @Patch('anomalies/:id')
  @RequirePermission('acp.logs.view')
  async updateAnomaly(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { status?: string; resolution?: string }): Promise<{ ok: true }> {
    const status = body?.status ?? 'open';
    if (!['open', 'assigned', 'resolved', 'dismissed'].includes(status)) {
      throw new BadRequestException('Ungültiger Status');
    }
    await this.anomalies.update(Number(id), status,
      status === 'assigned' ? req.account.id : null, body?.resolution ?? null);
    void this.acp.events.emit('web.mutation', {
      actor: { accountId: req.account.id },
      payload: { action: 'anomaly_update', anomalyId: Number(id), status },
    });
    return { ok: true };
  }
}
