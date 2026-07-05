import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard, AuthedRequest, RequirePermission } from '../auth/auth.guard';
import { GovernmentService } from './government.service';

@Controller('v1/ucp/government')
@UseGuards(AuthGuard)
export class GovernmentController {
  constructor(private readonly gov: GovernmentService) {}

  @Get('status')
  async status(@Req() req: AuthedRequest): Promise<{ isMember: boolean; grade: number | null }> {
    const member = await this.gov.governmentCharacter(req.account.id);
    return { isMember: member !== null, grade: member?.grade ?? null };
  }

  @Get('elections')
  elections(): Promise<unknown[]> {
    return this.gov.listElections();
  }

  @Post('elections/:id/candidacy')
  async candidacy(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { characterId?: number; statement?: string }): Promise<{ ok: true }> {
    await this.gov.registerCandidacy(req.account.id, Number(id),
      Number(body?.characterId), String(body?.statement ?? ''));
    return { ok: true };
  }

  @Post('elections/:id/vote')
  async vote(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { candidateId?: number }): Promise<{ ok: true }> {
    await this.gov.vote(req.account.id, Number(id), Number(body?.candidateId));
    return { ok: true };
  }

  @Get('proposals')
  proposals(): Promise<unknown[]> {
    return this.gov.listProposals();
  }

  @Post('proposals')
  async propose(@Req() req: AuthedRequest, @Body() body: {
    lawCode?: string; fine?: number; jailMinutes?: number; rationale?: string;
  }): Promise<{ id: number }> {
    return this.gov.propose(req.account.id, String(body?.lawCode ?? ''),
      Number(body?.fine ?? -1), Number(body?.jailMinutes ?? -1), String(body?.rationale ?? ''));
  }

  @Post('proposals/:id/vote')
  async voteProposal(@Req() req: AuthedRequest, @Param('id') id: string,
    @Body() body: { yes?: boolean }): Promise<{ ok: true }> {
    await this.gov.voteProposal(req.account.id, Number(id), body?.yes === true);
    return { ok: true };
  }
}

/** ACP: Wahlen anlegen (Wahlleitung). */
@Controller('v1/acp/government')
@UseGuards(AuthGuard)
export class AcpGovernmentController {
  constructor(private readonly gov: GovernmentService) {}

  @Post('elections')
  @RequirePermission('acp.government.manage')
  async create(@Req() req: AuthedRequest, @Body() body: {
    office?: string; title?: string; regHours?: number; voteHours?: number;
  }): Promise<{ id: number }> {
    return this.gov.createElection(req.account.id,
      String(body?.office ?? 'governor'), String(body?.title ?? 'Wahl'),
      Math.max(1, Number(body?.regHours ?? 48)), Math.max(1, Number(body?.voteHours ?? 48)));
  }
}
