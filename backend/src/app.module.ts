import { Module } from '@nestjs/common';
import { IngestModule } from './ingest/ingest.module';
import { LogstoreModule } from './logstore/logstore.module';
import { HealthController } from './health/health.controller';
import { AuthModule } from './auth/auth.module';
import { UcpModule } from './ucp/ucp.module';
import { AcpModule } from './acp/acp.module';

@Module({
  imports: [IngestModule, LogstoreModule, AuthModule, UcpModule, AcpModule],
  controllers: [HealthController],
})
export class AppModule {}
