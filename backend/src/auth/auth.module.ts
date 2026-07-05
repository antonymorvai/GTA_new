import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { AuthGuard } from './auth.guard';
import { gamedbProvider } from '../gamedb/gamedb.provider';
import { redisProvider } from '../redis/redis.provider';
import { EventPublisherService } from '../events/event-publisher.service';

@Module({
  controllers: [AuthController],
  providers: [AuthService, AuthGuard, gamedbProvider, redisProvider, EventPublisherService],
  exports: [AuthService, AuthGuard],
})
export class AuthModule {}
