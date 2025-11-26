import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ExecutionJob } from '../entities/execution-job.entity';
import { ExecutionJobStatusLog } from '../entities/execution-job-status-log.entity';
import { ExecutionProcessor } from './execution.processor';
import { LanguageServerManager } from './language-server-manager';

@Module({
  imports: [TypeOrmModule.forFeature([ExecutionJob, ExecutionJobStatusLog])],
  providers: [ExecutionProcessor, LanguageServerManager],
})
export class WorkerModule {}
