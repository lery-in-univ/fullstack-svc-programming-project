import { Injectable, OnModuleInit, OnModuleDestroy } from "@nestjs/common";
import { Worker, Job } from "bullmq";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { ExecutionJob } from "../entities/execution-job.entity";
import { ExecutionJobStatusLog } from "../entities/execution-job-status-log.entity";
import { ExecutionJobStatus } from "../entities/execution-job-status";
import { redisConfig } from "../config/redis.config";
import { join } from "path";
import { ulid } from "ulid";
import Docker, { Container } from "dockerode";

interface ExecutionJobData {
  jobId: string;
}

@Injectable()
export class ExecutionProcessor implements OnModuleInit, OnModuleDestroy {
  private worker: Worker;
  private docker: Docker;

  constructor(
    @InjectRepository(ExecutionJob)
    private readonly executionJobRepository: Repository<ExecutionJob>,

    @InjectRepository(ExecutionJobStatusLog)
    private readonly executionJobStatusLogRepository: Repository<ExecutionJobStatusLog>
  ) {
    this.docker = new Docker({
      socketPath: "/var/run/docker.sock",
    });
  }

  async onModuleInit() {
    this.worker = new Worker(
      "execution",
      async (job: Job<ExecutionJobData>) => {
        return this.processJob(job);
      },
      {
        connection: redisConfig,
        concurrency: 4,
      }
    );

    this.worker.on("completed", (job) => {
      console.log(`Job ${job.id} completed successfully`);
    });

    this.worker.on("failed", (job, err) => {
      console.error(`Job ${job?.id} failed with error:`, err);
    });

    console.log("Execution worker started with concurrency: 4");
  }

  async onModuleDestroy() {
    await this.worker?.close();
  }

  private async processJob(job: Job<ExecutionJobData>): Promise<void> {
    const { jobId } = job.data;

    console.log(`Processing execution job: ${jobId}`);
    console.log(`Job data:`, JSON.stringify(job.data, null, 2));

    try {
      const executionJob = await this.executionJobRepository.findOne({
        where: { id: jobId },
      });

      if (!executionJob) {
        throw new Error(`Execution job ${jobId} not found`);
      }

      await this.createStatusLog(jobId, ExecutionJobStatus.READY);

      const basePath = process.env.CODE_FILES_PATH || "/code-files";
      const fullPath = join(
        basePath,
        executionJob.sessionId,
        executionJob.filePath
      );

      console.log("Creating Dart container...");

      const volumeName = process.env.CODE_FILES_VOLUME || "code-files";
      const container = (await this.docker.createContainer({
        Image: "dart:3.9.4",
        Cmd: ["dart", "run", fullPath],
        AttachStdout: true,
        AttachStderr: true,
        Tty: true,
        HostConfig: {
          Binds: [`${volumeName}:/code-files:ro`],
          Memory: 256 * 1024 * 1024, // 256MB
          NanoCpus: 0.5 * 1e9, // 0.5 CPU
          NetworkMode: "none", // 네트워크 접근 제한
        },
      })) as unknown as Container;

      console.log(`Container created: ${container.id}`);

      await container.start();
      await this.createStatusLog(jobId, ExecutionJobStatus.RUNNING);

      console.log("Container started");

      // 30초 타임아웃 적용
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error("Execution timeout (30s)")), 30000)
      );

      const waitPromise = container.wait();

      let waitResult;
      try {
        waitResult = await Promise.race([waitPromise, timeoutPromise]);
      } catch (timeoutError) {
        await container.kill().catch(() => {});
        await container.remove().catch(() => {});

        await this.executionJobRepository.update(jobId, {
          error: "Execution timeout (30s)",
          exitCode: -1,
          completedAt: new Date(),
        });

        await this.createStatusLog(
          jobId,
          ExecutionJobStatus.FINISHED_WITH_ERROR
        );
        throw timeoutError;
      }

      console.log("Container finished with exit code:", waitResult.StatusCode);

      const logs = await container.logs({
        stdout: true,
        stderr: true,
        follow: false,
      });

      const output = logs.toString();
      console.log("Container output:", output);

      await container.remove();
      console.log("Container removed");

      // Update job with results
      const exitCode = waitResult.StatusCode;
      if (exitCode === 0) {
        await this.executionJobRepository.update(jobId, {
          output,
          exitCode,
          completedAt: new Date(),
        });

        await this.createStatusLog(
          jobId,
          ExecutionJobStatus.FINISHED_WITH_SUCCESS
        );
      } else {
        await this.executionJobRepository.update(jobId, {
          error: output,
          exitCode,
          completedAt: new Date(),
        });

        await this.createStatusLog(
          jobId,
          ExecutionJobStatus.FINISHED_WITH_ERROR
        );
      }
    } catch (error) {
      console.error(`Error processing job ${jobId}:`, error);

      await this.executionJobRepository.update(jobId, {
        error: error.message || String(error),
        exitCode: -1,
        completedAt: new Date(),
      });

      await this.createStatusLog(jobId, ExecutionJobStatus.FAILED);
      throw error;
    }
  }

  private async createStatusLog(
    jobId: string,
    status: ExecutionJobStatus
  ): Promise<void> {
    const statusLog = this.executionJobStatusLogRepository.create({
      id: ulid(),
      jobId,
      status,
      createdAt: new Date(),
    });
    await this.executionJobStatusLogRepository.save(statusLog);
    console.log(`Job ${jobId} status updated to ${status}`);
  }
}
