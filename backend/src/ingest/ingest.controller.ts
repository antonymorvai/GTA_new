import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Post,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { timingSafeEqual } from 'crypto';
import { IngestBatchSchema } from '../common/event-envelope';
import { IngestService } from './ingest.service';

/**
 * Ingest-Endpunkt für den Gameserver.
 * SICHERHEIT: nur über das interne Docker-Netz erreichbar (der Proxy blockt
 * /api/v1/ingest/* öffentlich) + Bearer-Token-Pflicht.
 */
@Controller('v1/ingest')
export class IngestController {
  constructor(private readonly ingest: IngestService) {}

  private assertToken(authorization?: string): void {
    const expected = process.env.INGEST_TOKEN ?? '';
    const provided = authorization?.replace(/^Bearer\s+/i, '') ?? '';
    if (expected.length === 0) {
      throw new UnauthorizedException('INGEST_TOKEN nicht konfiguriert');
    }
    const a = Buffer.from(provided);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException();
    }
  }

  @Post('events')
  @HttpCode(204)
  async ingestEvents(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
  ): Promise<void> {
    this.assertToken(authorization);

    const parsed = IngestBatchSchema.safeParse(body);
    if (!parsed.success) {
      // Der Logger im Gameserver puffert bei !2xx auf Disk — ein defektes
      // Batch darf aber nicht ewig retried werden, daher 400 (kein Retry-Fall
      // im Logger: 400er landen im Dead-Letter des Buffers beim Nachspielen).
      throw new BadRequestException(parsed.error.issues.slice(0, 5));
    }

    await this.ingest.publish(parsed.data.events);
  }
}
