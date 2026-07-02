import { Module } from '@nestjs/common';
import { IngestController } from './ingest.controller';
import { IngestService } from './ingest.service';
import { redisProvider } from '../redis/redis.provider';

@Module({
  controllers: [IngestController],
  providers: [IngestService, redisProvider],
})
export class IngestModule {}
