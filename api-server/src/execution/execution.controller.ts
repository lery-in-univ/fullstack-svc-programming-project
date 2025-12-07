import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  Body,
} from '@nestjs/common';
import { ExecutionService } from './execution.service';
import { ExecutionJob } from 'src/entities/execution-job.entity';
import { ExecutionJobStatusLog } from 'src/entities/execution-job-status-log.entity';

@Controller()
export class ExecutionController {
  constructor(private readonly executionService: ExecutionService) {}

  @Post('/sessions/:sessionId/execution-jobs')
  async createExecutionJob(@Param('sessionId') sessionId: string) {
    const job = await this.executionService.createExecutionJob(sessionId);

    return {
      id: job.id,
      status: 'QUEUED',
      createdAt: job.createdAt,
    };
  }

  @Get('/sessions/:sessionId/execution-jobs')
  async getExecutionJobs(@Param('sessionId') sessionId: string) {
    const jobs =
      await this.executionService.findExecutionJobsBySessionId(sessionId);

    return jobs.map((job: ExecutionJob) => {
      const statuses: ExecutionJobStatusLog[] = job.statuses || [];
      const latestStatus =
        statuses.length > 0
          ? [...statuses].sort(
              (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
            )[0]
          : null;

      return {
        id: job.id,
        status: latestStatus?.status || 'UNKNOWN',
        filePath: job.filePath,
        createdAt: job.createdAt,
      };
    });
  }

  @Get('/execution-jobs/:jobId')
  async getExecutionJob(@Param('jobId') id: string) {
    const job = await this.executionService.findExecutionJobById(id);

    if (!job) {
      throw new NotFoundException('Execution job not found');
    }

    const statuses: ExecutionJobStatusLog[] = job.statuses || [];
    const sortedStatuses = [...statuses].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );

    const latestStatus =
      sortedStatuses.length > 0
        ? sortedStatuses[sortedStatuses.length - 1]
        : null;

    return {
      id: job.id,
      status: latestStatus?.status || 'UNKNOWN',
      filePath: job.filePath,
      createdAt: job.createdAt,
      output: job.output,
      error: job.error,
      exitCode: job.exitCode,
      completedAt: job.completedAt,
      statusHistory: sortedStatuses.map((status: ExecutionJobStatusLog) => ({
        status: status.status,
        createdAt: status.createdAt,
      })),
    };
  }
}
