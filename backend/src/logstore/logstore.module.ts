import { Module } from '@nestjs/common';
import { ConsumerService } from './consumer.service';
import { LogstoreWriter } from './logstore.writer';
import { AlertService } from './alert.service';
import { redisProvider } from '../redis/redis.provider';

@Module({
  providers: [ConsumerService, LogstoreWriter, AlertService, redisProvider],
})
export class LogstoreModule {}
