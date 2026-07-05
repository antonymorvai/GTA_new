import { Module } from '@nestjs/common';
import { UcpController } from './ucp.controller';
import { UcpWorkflowController } from './workflow.controller';
import { AuthModule } from '../auth/auth.module';
import { gamedbProvider } from '../gamedb/gamedb.provider';
import { redisProvider } from '../redis/redis.provider';
import { EventPublisherService } from '../events/event-publisher.service';

@Module({
  imports: [AuthModule],
  controllers: [UcpController, UcpWorkflowController],
  providers: [gamedbProvider, redisProvider, EventPublisherService],
})
export class UcpModule {}
