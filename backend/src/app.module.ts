import { Module } from '@nestjs/common';
import { IngestModule } from './ingest/ingest.module';
import { LogstoreModule } from './logstore/logstore.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [IngestModule, LogstoreModule],
  controllers: [HealthController],
})
export class AppModule {}
