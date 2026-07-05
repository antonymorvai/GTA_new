import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthService } from './auth.service';
import type { Request } from 'express';

export const PERMISSION_KEY = 'required_permission';
/** Deklariert die nötige RBAC-Permission für einen Endpunkt. */
export const RequirePermission = (permission: string) => SetMetadata(PERMISSION_KEY, permission);

export interface AuthedRequest extends Request {
  account: { id: number; username: string; permissions: string[] };
}

/**
 * JWT-Auth + RBAC in einem Guard: ohne @RequirePermission reicht ein gültiges
 * Login (UCP); mit Permission wird die Rechtematrix der Spiel-DB geprüft (ACP).
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly auth: AuthService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const token = req.headers.authorization?.replace(/^Bearer\s+/i, '');
    if (!token) throw new UnauthorizedException('Nicht angemeldet');

    const payload = this.auth.verifyToken(token);
    const permissions = await this.auth.getPermissions(payload.sub);
    req.account = { id: payload.sub, username: payload.username, permissions };

    const required = this.reflector.getAllAndOverride<string | undefined>(PERMISSION_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (required && !permissions.includes(required)) {
      throw new ForbiddenException(`Fehlende Berechtigung: ${required}`);
    }
    return true;
  }
}
