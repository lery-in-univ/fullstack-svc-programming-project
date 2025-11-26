import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ExecutionJob } from 'src/entities/execution-job.entity';
import { ExecutionJobStatusLog } from 'src/entities/execution-job-status-log.entity';
import { QueueModule } from 'src/queue/queue.module';
import { SessionsModule } from '../sessions/sessions.module';
import { ExecutionController } from './execution.controller';
import { ExecutionService } from './execution.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([ExecutionJob, ExecutionJobStatusLog]),
    QueueModule,
    SessionsModule,
  ],
  controllers: [ExecutionController],
  providers: [ExecutionService],
})
export class ExecutionModule {}
