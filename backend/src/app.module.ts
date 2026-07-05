import { Module } from '@nestjs/common';
import { IngestModule } from './ingest/ingest.module';
import { LogstoreModule } from './logstore/logstore.module';
import { HealthController } from './health/health.controller';
import { PublicController } from './health/public.controller';
import { gamedbProvider } from './gamedb/gamedb.provider';
import { AuthModule } from './auth/auth.module';
import { UcpModule } from './ucp/ucp.module';
import { AcpModule } from './acp/acp.module';
import { GovernmentModule } from './government/government.module';

@Module({
  imports: [IngestModule, LogstoreModule, AuthModule, UcpModule, AcpModule, GovernmentModule],
  controllers: [HealthController, PublicController],
  providers: [gamedbProvider],
})
export class AppModule {}
