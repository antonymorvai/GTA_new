import { Controller, Get } from '@nestjs/common';

@Controller()
export class HealthController {
  @Get('healthz')
  health(): { status: string; ts: number } {
    return { status: 'ok', ts: Date.now() };
  }
}
