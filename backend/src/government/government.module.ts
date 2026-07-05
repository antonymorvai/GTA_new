import { Module } from '@nestjs/common';
import { GovernmentService } from './government.service';
import { AcpGovernmentController, GovernmentController } from './government.controller';
import { AuthModule } from '../auth/auth.module';
import { gamedbProvider } from '../gamedb/gamedb.provider';
import { redisProvider } from '../redis/redis.provider';
import { EventPublisherService } from '../events/event-publisher.service';

@Module({
  imports: [AuthModule],
  controllers: [GovernmentController, AcpGovernmentController],
  providers: [GovernmentService, gamedbProvider, redisProvider, EventPublisherService],
})
export class GovernmentModule {}
