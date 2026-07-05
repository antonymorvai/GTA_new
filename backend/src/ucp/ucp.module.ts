import { Module } from '@nestjs/common';
import { UcpController } from './ucp.controller';
import { AuthModule } from '../auth/auth.module';
import { gamedbProvider } from '../gamedb/gamedb.provider';

@Module({
  imports: [AuthModule],
  controllers: [UcpController],
  providers: [gamedbProvider],
})
export class UcpModule {}
