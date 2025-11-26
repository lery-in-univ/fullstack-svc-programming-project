import {
  Inject,
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Queue } from 'bullmq';
import { ExecutionJob } from 'src/entities/execution-job.entity';
import { ExecutionJobStatusLog } from 'src/entities/execution-job-status-log.entity';
import { ExecutionJobStatus } from 'src/entities/execution-job-status';
import { EXECUTION_QUEUE } from 'src/queue/queue.provider';
import { DataSource, Repository } from 'typeorm';
import { ulid } from 'ulid';
import { promises as fs } from 'fs';
import { join } from 'path';
import { SessionsService } from '../sessions/sessions.service';

@Injectable()
export class ExecutionService {
  constructor(
    @InjectRepository(ExecutionJob)
    private readonly executionJobRepository: Repository<ExecutionJob>,

    private readonly dataSource: DataSource,

    @Inject(EXECUTION_QUEUE)
    private readonly executionQueue: Queue,

    private readonly sessionsService: SessionsService,
  ) {}

  async createExecutionJob(
    userId: string,
    sessionId: string,
  ): Promise<ExecutionJob> {
    const fileName = 'main.dart'; // 항상 고정

    // 1. 세션 소유권 검증
    const sessionData = await this.sessionsService.getSession(sessionId);
    if (!sessionData) {
      throw new NotFoundException('Session not found');
    }
    if (sessionData.userId !== userId) {
      throw new ForbiddenException('Session does not belong to user');
    }

    // 2. main.dart 파일 존재 확인
    const basePath = process.env.CODE_FILES_PATH || '/code-files';
    const fullPath = join(basePath, sessionId, fileName);
    try {
      await fs.access(fullPath);
    } catch {
      throw new NotFoundException(
        `File ${fileName} not found in session ${sessionId}`,
      );
    }

    // 3. sessionId와 fileName으로 job 생성
    const newJob = await this.dataSource.transaction(async (em) => {
      const executionJobRepository = em.getRepository(ExecutionJob);
      const executionJobStatusLogRepository = em.getRepository(
        ExecutionJobStatusLog,
      );

      const jobId = ulid();
      const now = new Date();

      const newJob = executionJobRepository.create({
        id: jobId,
        userId,
        sessionId,
        filePath: fileName,
        createdAt: now,
      });
      await executionJobRepository.save(newJob);

      const initialStatusLog = executionJobStatusLogRepository.create({
        id: ulid(),
        jobId,
        status: ExecutionJobStatus.QUEUED,
        createdAt: now,
      });
      await executionJobStatusLogRepository.save(initialStatusLog);

      return newJob;
    });

    // 4. 큐에 발행
    await this.executionQueue.add('execute-code', {
      jobId: newJob.id,
    });

    // 5. 세션 TTL 갱신
    await this.sessionsService.updateLastActivity(sessionId);

    return newJob;
  }

  async findExecutionJobsByUserId(
    userId: string,
  ): Promise<(ExecutionJob & { statuses: ExecutionJobStatusLog[] })[]> {
    const jobs = await this.executionJobRepository.find({
      where: { userId },
      relations: { statuses: true },
      order: { createdAt: 'DESC' },
    });
    return jobs as (ExecutionJob & { statuses: ExecutionJobStatusLog[] })[];
  }

  async findExecutionJobById(
    jobId: string,
    userId: string,
  ): Promise<(ExecutionJob & { statuses: ExecutionJobStatusLog[] }) | null> {
    const job = await this.executionJobRepository.findOne({
      where: { id: jobId, userId },
      relations: { statuses: true },
    });
    return job as (ExecutionJob & { statuses: ExecutionJobStatusLog[] }) | null;
  }
}
