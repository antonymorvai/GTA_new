import {
  BadRequestException,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { authenticator } from 'otplib';
import * as jwt from 'jsonwebtoken';
import { GAMEDB, GameDb } from '../gamedb/gamedb.provider';
import { EventPublisherService } from '../events/event-publisher.service';
import type { RowDataPacket } from 'mysql2';

export interface JwtPayload {
  sub: number;
  username: string;
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(GAMEDB) private readonly db: GameDb,
    private readonly events: EventPublisherService,
  ) {}

  private jwtSecret(): string {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET nicht konfiguriert');
    return secret;
  }

  signToken(payload: JwtPayload): string {
    return jwt.sign(payload, this.jwtSecret(), { expiresIn: '12h' });
  }

  verifyToken(token: string): JwtPayload {
    try {
      return jwt.verify(token, this.jwtSecret()) as unknown as JwtPayload;
    } catch {
      throw new UnauthorizedException('Ungültige oder abgelaufene Sitzung');
    }
  }

  async register(username: string, email: string, password: string, ip: string): Promise<void> {
    if (!/^[\w.-]{3,32}$/.test(username)) throw new BadRequestException('Ungültiger Benutzername');
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new BadRequestException('Ungültige E-Mail');
    if (password.length < 10) throw new BadRequestException('Passwort: mindestens 10 Zeichen');

    const [existing] = await this.db.query<RowDataPacket[]>(
      'SELECT id FROM accounts WHERE username = ? OR email = ?',
      [username, email],
    );
    if (existing.length > 0) throw new BadRequestException('Benutzername oder E-Mail bereits vergeben');

    const hash = await argon2.hash(password, { type: argon2.argon2id });
    const [result] = await this.db.query(
      'INSERT INTO accounts (username, email, password_hash) VALUES (?, ?, ?)',
      [username, email, hash],
    );
    const accountId = (result as { insertId: number }).insertId;

    await this.events.emit('web.mutation', {
      actor: { accountId },
      payload: { action: 'register', username, ip },
    });
  }

  async login(
    username: string,
    password: string,
    totpToken: string | undefined,
    ip: string,
  ): Promise<{ token: string; accountId: number }> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      'SELECT id, username, password_hash, totp_secret, totp_enabled FROM accounts WHERE username = ?',
      [username],
    );
    const account = rows[0];

    const fail = async (reason: string): Promise<never> => {
      await this.events.emit('web.login', {
        actor: account ? { accountId: account.id } : undefined,
        payload: { success: false, username, reason, ip },
      });
      throw new UnauthorizedException('Anmeldung fehlgeschlagen');
    };

    if (!account || !account.password_hash) return fail('unknown_user');
    if (!(await argon2.verify(account.password_hash, password))) return fail('bad_password');

    if (account.totp_enabled === 1) {
      const secret = account.totp_secret?.toString('utf8');
      if (!totpToken || !secret || !authenticator.verify({ token: totpToken, secret })) {
        return fail('bad_totp');
      }
    }

    await this.db.query('UPDATE accounts SET last_login_at = NOW(3) WHERE id = ?', [account.id]);
    await this.events.emit('web.login', {
      actor: { accountId: account.id },
      payload: { success: true, username, ip },
    });

    return { token: this.signToken({ sub: account.id, username: account.username }), accountId: account.id };
  }

  /** TOTP-Setup: Secret erzeugen (aktiv erst nach enableTotp-Verifikation). */
  async setupTotp(accountId: number, username: string): Promise<{ otpauthUrl: string; secret: string }> {
    const secret = authenticator.generateSecret();
    await this.db.query('UPDATE accounts SET totp_secret = ?, totp_enabled = 0 WHERE id = ?', [
      Buffer.from(secret, 'utf8'),
      accountId,
    ]);
    return { otpauthUrl: authenticator.keyuri(username, 'HardcoreRP', secret), secret };
  }

  async enableTotp(accountId: number, token: string): Promise<void> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      'SELECT totp_secret FROM accounts WHERE id = ?',
      [accountId],
    );
    const secret = rows[0]?.totp_secret?.toString('utf8');
    if (!secret || !authenticator.verify({ token, secret })) {
      throw new BadRequestException('TOTP-Code ungültig');
    }
    await this.db.query('UPDATE accounts SET totp_enabled = 1 WHERE id = ?', [accountId]);
    await this.events.emit('web.mutation', {
      actor: { accountId },
      payload: { action: 'totp_enabled' },
    });
  }

  async getPermissions(accountId: number): Promise<string[]> {
    const [rows] = await this.db.query<RowDataPacket[]>(
      `SELECT DISTINCT p.name FROM account_roles ar
       JOIN role_permissions rp ON rp.role_id = ar.role_id
       JOIN permissions p ON p.id = rp.permission_id
       WHERE ar.account_id = ?`,
      [accountId],
    );
    return rows.map((r) => r.name as string);
  }
}
