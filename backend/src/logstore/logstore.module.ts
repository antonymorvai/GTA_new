import { Module } from '@nestjs/common';
import { ConsumerService } from './consumer.service';
import { LogstoreWriter } from './logstore.writer';
import { redisProvider } from '../redis/redis.provider';

@Module({
  providers: [ConsumerService, LogstoreWriter, redisProvider],
})
export class LogstoreModule {}
