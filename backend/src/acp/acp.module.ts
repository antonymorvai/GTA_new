import { Module } from '@nestjs/common';
import { AcpController } from './acp.controller';
import { AcpWorkflowController } from './workflow.controller';
import { AcpService } from './acp.service';
import { AnomalyService } from './anomaly.service';
import { AuthModule } from '../auth/auth.module';
import { gamedbProvider } from '../gamedb/gamedb.provider';
import { redisProvider } from '../redis/redis.provider';
import { EventPublisherService } from '../events/event-publisher.service';

@Module({
  imports: [AuthModule],
  controllers: [AcpController, AcpWorkflowController],
  providers: [AcpService, AnomalyService, gamedbProvider, redisProvider, EventPublisherService],
})
export class AcpModule {}
