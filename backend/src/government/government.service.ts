import { BadRequestException, Inject, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import { EventPublisherService } from '../events/event-publisher.service';
import type { RowDataPacket } from 'mysql2';

/**
 * Regierung: Gesetzgebungs-Workflow + Wahlen.
 * Ein Scheduler schließt abgelaufene Abstimmungen/Wahlphasen automatisch:
 * angenommene Gesetzentwürfe treten SOFORT in Kraft (laws + law_history +
 * law.change — MDT/Bußgeld-Engine lesen immer den aktiven Stand),
 * Wahlsieger erhalten automatisch das Governor-Amt (job government, Grade 2).
 */
@Injectable()
export class GovernmentService implements OnModuleInit {
  private readonly logger = new Logger(GovernmentService.name);

  constructor(
    @Inject(GAMEDB) private readonly db: GameDb,
    private readonly events: EventPublisherService,
  ) {}

  onModuleInit(): void {
    setInterval(() => void this.tick().catch((e) => this.logger.error(e.message)), 60000);
  }

  /** Charakter des Accounts, der Regierungsmitglied ist (oder null). */
  async governmentCharacter(accountId: number): Promise<{ id: number; grade: number } | null> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT c.id, cj.grade FROM characters c
       JOIN character_jobs cj ON cj.character_id = c.id
       JOIN jobs j ON j.id = cj.job_id AND j.name = 'government'
       WHERE c.account_id = ? AND c.deleted_at IS NULL LIMIT 1`, [accountId]);
    return rows.length > 0 ? { id: rows[0].id, grade: rows[0].grade } : null;
  }

  // --- Gesetzgebung ---

  async listProposals(): Promise<unknown[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT p.*, l.title AS law_title, l.fine AS current_fine, l.jail_minutes AS current_jail,
              c.first_name, c.last_name
       FROM law_proposals p
       JOIN laws l ON l.code = p.law_code
       JOIN characters c ON c.id = p.proposed_by
       ORDER BY p.created_at DESC LIMIT 30`);
    return rows;
  }

  async propose(accountId: number, lawCode: string, fine: number, jailMinutes: number,
    rationale: string): Promise<{ id: number }> {
    const member = await this.governmentCharacter(accountId);
    if (!member) throw new BadRequestException('Nur Regierungsmitglieder können Gesetzentwürfe einbringen.');
    if (rationale.trim().length < 30) throw new BadRequestException('Begründung: mindestens 30 Zeichen.');
    if (fine < 0 || jailMinutes < 0 || fine > 100000000 || jailMinutes > 240) {
      throw new BadRequestException('Werte außerhalb des zulässigen Rahmens.');
    }

    const [laws] = await this.db.query<RowDataPacket[]>(
      'SELECT code FROM laws WHERE code = ? AND active = 1', [lawCode]);
    if (laws.length === 0) throw new NotFoundException('Unbekannter Gesetzes-Code.');

    const [open] = await this.db.query<RowDataPacket[]>(
      `SELECT id FROM law_proposals WHERE law_code = ? AND status = 'voting'`, [lawCode]);
    if (open.length > 0) throw new BadRequestException('Zu diesem Gesetz läuft bereits eine Abstimmung.');

    const [result] = await this.db.query(
      `INSERT INTO law_proposals (law_code, new_fine, new_jail_minutes, rationale, proposed_by, voting_ends_at)
       VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(3), INTERVAL 24 HOUR))`,
      [lawCode, Math.floor(fine), Math.floor(jailMinutes), rationale.trim(), member.id]);
    const id = (result as { insertId: number }).insertId;

    await this.events.emit('law.vote', {
      actor: { accountId, characterId: member.id },
      target: { kind: 'law', id: lawCode },
      payload: { action: 'proposed', proposalId: id, newFine: fine, newJailMinutes: jailMinutes },
    });
    return { id };
  }

  async voteProposal(accountId: number, proposalId: number, yes: boolean): Promise<void> {
    const member = await this.governmentCharacter(accountId);
    if (!member) throw new BadRequestException('Nur Regierungsmitglieder stimmen über Gesetze ab.');

    const [proposals] = await this.db.query<RowDataPacket[]>(
      `SELECT id FROM law_proposals WHERE id = ? AND status = 'voting' AND voting_ends_at > NOW(3)`,
      [proposalId]);
    if (proposals.length === 0) throw new NotFoundException('Abstimmung nicht (mehr) offen.');

    const [existing] = await this.db.query<RowDataPacket[]>(
      'SELECT 1 FROM proposal_votes WHERE proposal_id = ? AND character_id = ?', [proposalId, member.id]);
    if (existing.length > 0) throw new BadRequestException('Du hast bereits abgestimmt.');

    await this.db.query(
      'INSERT INTO proposal_votes (proposal_id, character_id, vote_yes) VALUES (?, ?, ?)',
      [proposalId, member.id, yes ? 1 : 0]);
    await this.db.query(
      `UPDATE law_proposals SET votes_yes = votes_yes + ?, votes_no = votes_no + ? WHERE id = ?`,
      [yes ? 1 : 0, yes ? 0 : 1, proposalId]);

    await this.events.emit('law.vote', {
      actor: { accountId, characterId: member.id },
      payload: { action: 'voted', proposalId, voteYes: yes },   // namentlich = Parlaments-Transparenz
    });
  }

  private async enactProposal(proposal: RowDataPacket): Promise<void> {
    const [laws] = await this.db.query<RowDataPacket[]>(
      'SELECT * FROM laws WHERE code = ?', [proposal.law_code]);
    const law = laws[0];
    const newVersion = law.version + 1;

    await this.db.query('UPDATE laws SET fine = ?, jail_minutes = ?, version = ? WHERE code = ?',
      [proposal.new_fine, proposal.new_jail_minutes, newVersion, proposal.law_code]);
    await this.db.query(
      'INSERT INTO law_history (law_code, version, snapshot, changed_by) VALUES (?, ?, ?, ?)',
      [proposal.law_code, newVersion, JSON.stringify({
        code: proposal.law_code, title: law.title, fine: proposal.new_fine,
        jailMinutes: proposal.new_jail_minutes, version: newVersion, viaProposal: proposal.id,
      }), proposal.proposed_by]);
    await this.db.query(
      `UPDATE law_proposals SET status = 'enacted', enacted_at = NOW(3) WHERE id = ?`, [proposal.id]);

    await this.events.emit('law.change', {
      target: { kind: 'law', id: proposal.law_code },
      payload: {
        code: proposal.law_code, version: newVersion,
        before: { fine: law.fine, jailMinutes: law.jail_minutes },
        after: { fine: proposal.new_fine, jailMinutes: proposal.new_jail_minutes },
        viaProposal: proposal.id, votesYes: proposal.votes_yes, votesNo: proposal.votes_no,
      },
    });
  }

  // --- Wahlen ---

  async listElections(): Promise<unknown[]> {
    const [elections] = await this.db.query<RowDataPacket[]>(
      `SELECT * FROM elections ORDER BY created_at DESC LIMIT 10`);
    for (const e of elections) {
      const [candidates] = await this.db.query<RowDataPacket[]>(
        `SELECT ec.id, ec.statement, c.first_name, c.last_name,
                ${e.phase === 'closed' ? 'ec.votes' : 'NULL AS votes'}
         FROM election_candidates ec JOIN characters c ON c.id = ec.character_id
         WHERE ec.election_id = ?`, [e.id]);
      (e as Record<string, unknown>).candidates = candidates;
    }
    return elections;
  }

  async createElection(accountId: number, office: string, title: string,
    regHours: number, voteHours: number): Promise<{ id: number }> {
    const [result] = await this.db.query(
      `INSERT INTO elections (office, title, registration_ends_at, voting_ends_at, created_by)
       VALUES (?, ?, DATE_ADD(NOW(3), INTERVAL ? HOUR), DATE_ADD(NOW(3), INTERVAL ? HOUR), ?)`,
      [office, title, regHours, regHours + voteHours, accountId]);
    const id = (result as { insertId: number }).insertId;
    await this.events.emit('election.create', {
      actor: { accountId },
      payload: { electionId: id, office, title, regHours, voteHours },
    });
    return { id };
  }

  async registerCandidacy(accountId: number, electionId: number, characterId: number,
    statement: string): Promise<void> {
    const [elections] = await this.db.query<RowDataPacket[]>(
      `SELECT id FROM elections WHERE id = ? AND phase = 'registration'`, [electionId]);
    if (elections.length === 0) throw new BadRequestException('Kandidaten-Registrierung nicht (mehr) offen.');

    const [chars] = await this.db.query<RowDataPacket[]>(
      'SELECT id FROM characters WHERE id = ? AND account_id = ? AND deleted_at IS NULL',
      [characterId, accountId]);
    if (chars.length === 0) throw new BadRequestException('Charakter gehört nicht zu deinem Account.');
    if (statement.trim().length < 30) throw new BadRequestException('Wahlprogramm: mindestens 30 Zeichen.');

    await this.db.query(
      'INSERT INTO election_candidates (election_id, character_id, statement) VALUES (?, ?, ?)',
      [electionId, characterId, statement.trim()]);
    await this.events.emit('election.candidacy', {
      actor: { accountId, characterId },
      payload: { electionId, characterId },
    });
  }

  async vote(accountId: number, electionId: number, candidateId: number): Promise<void> {
    const [elections] = await this.db.query<RowDataPacket[]>(
      `SELECT id FROM elections WHERE id = ? AND phase = 'voting'`, [electionId]);
    if (elections.length === 0) throw new BadRequestException('Die Wahl ist nicht in der Abstimmungsphase.');

    const [voted] = await this.db.query<RowDataPacket[]>(
      'SELECT 1 FROM election_voters WHERE election_id = ? AND account_id = ?', [electionId, accountId]);
    if (voted.length > 0) throw new BadRequestException('Du hast bereits gewählt.');

    const [candidates] = await this.db.query<RowDataPacket[]>(
      'SELECT id FROM election_candidates WHERE id = ? AND election_id = ?', [candidateId, electionId]);
    if (candidates.length === 0) throw new NotFoundException('Kandidat nicht gefunden.');

    // Geheime Wahl: Teilnahme und Stimme getrennt, Stimme NIE personenbezogen
    await this.db.query(
      'INSERT INTO election_voters (election_id, account_id) VALUES (?, ?)', [electionId, accountId]);
    await this.db.query(
      'UPDATE election_candidates SET votes = votes + 1 WHERE id = ?', [candidateId]);

    await this.events.emit('election.vote', {
      actor: { accountId },
      payload: { electionId },   // bewusst OHNE Kandidat — Wahlgeheimnis
    });
  }

  // --- Scheduler ---

  async tick(): Promise<void> {
    // Gesetzentwürfe schließen
    const [dueProposals] = await this.db.query<RowDataPacket[]>(
      `SELECT * FROM law_proposals WHERE status = 'voting' AND voting_ends_at <= NOW(3)`);
    for (const proposal of dueProposals) {
      if (proposal.votes_yes > proposal.votes_no) {
        await this.db.query(`UPDATE law_proposals SET status = 'passed' WHERE id = ?`, [proposal.id]);
        await this.enactProposal(proposal);
        this.logger.log(`Gesetzentwurf #${proposal.id} (${proposal.law_code}) in Kraft getreten.`);
      } else {
        await this.db.query(`UPDATE law_proposals SET status = 'rejected' WHERE id = ?`, [proposal.id]);
      }
    }

    // Wahlphasen weiterschalten
    await this.db.query(
      `UPDATE elections SET phase = 'voting'
       WHERE phase = 'registration' AND registration_ends_at <= NOW(3)`);

    const [dueElections] = await this.db.query<RowDataPacket[]>(
      `SELECT * FROM elections WHERE phase = 'voting' AND voting_ends_at <= NOW(3)`);
    for (const election of dueElections) {
      const [winners] = await this.db.query<RowDataPacket[]>(
        `SELECT character_id, votes FROM election_candidates
         WHERE election_id = ? ORDER BY votes DESC LIMIT 1`, [election.id]);
      const winner = winners[0] ?? null;

      await this.db.query(
        `UPDATE elections SET phase = 'closed', winner_character_id = ? WHERE id = ?`,
        [winner?.character_id ?? null, election.id]);

      if (winner) {
        // Amtseinführung: Governor-Job automatisch zuweisen
        const [jobs] = await this.db.query<RowDataPacket[]>(
          `SELECT id FROM jobs WHERE name = 'government'`);
        await this.db.query(
          `INSERT INTO character_jobs (character_id, job_id, grade, on_duty)
           VALUES (?, ?, 2, 0)
           ON DUPLICATE KEY UPDATE job_id = VALUES(job_id), grade = 2`,
          [winner.character_id, jobs[0].id]);
      }

      await this.events.emit('election.closed', {
        payload: { electionId: election.id, office: election.office,
                   winnerCharacterId: winner?.character_id ?? null, votes: winner?.votes ?? 0 },
      });
      this.logger.log(`Wahl #${election.id} geschlossen.`);
    }
  }
}
