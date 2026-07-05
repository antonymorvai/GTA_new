import { Body, Controller, Get, Ip, Post, UseGuards, Req } from '@nestjs/common';
import { z } from 'zod';
import { BadRequestException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthGuard, AuthedRequest } from './auth.guard';

const RegisterSchema = z.object({
  username: z.string().min(3).max(32),
  email: z.string().max(255),
  password: z.string().min(10).max(200),
});

const LoginSchema = z.object({
  username: z.string().min(1).max(32),
  password: z.string().min(1).max(200),
  totp: z.string().max(8).optional(),
});

@Controller('v1/auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  async register(@Body() body: unknown, @Ip() ip: string): Promise<{ ok: true }> {
    const data = RegisterSchema.safeParse(body);
    if (!data.success) throw new BadRequestException(data.error.issues[0]?.message);
    await this.auth.register(data.data.username, data.data.email, data.data.password, ip);
    return { ok: true };
  }

  @Post('login')
  async login(@Body() body: unknown, @Ip() ip: string): Promise<{ token: string }> {
    const data = LoginSchema.safeParse(body);
    if (!data.success) throw new BadRequestException('Ungültige Eingabe');
    const { token } = await this.auth.login(data.data.username, data.data.password, data.data.totp, ip);
    return { token };
  }

  @Get('me')
  @UseGuards(AuthGuard)
  async me(@Req() req: AuthedRequest): Promise<{ id: number; username: string; permissions: string[] }> {
    return req.account;
  }

  @Post('totp/setup')
  @UseGuards(AuthGuard)
  async totpSetup(@Req() req: AuthedRequest): Promise<{ otpauthUrl: string; secret: string }> {
    return this.auth.setupTotp(req.account.id, req.account.username);
  }

  @Post('totp/enable')
  @UseGuards(AuthGuard)
  async totpEnable(@Req() req: AuthedRequest, @Body() body: { token?: string }): Promise<{ ok: true }> {
    await this.auth.enableTotp(req.account.id, String(body?.token ?? ''));
    return { ok: true };
  }
}
