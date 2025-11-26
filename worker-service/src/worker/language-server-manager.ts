import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from "@nestjs/common";
import Docker from "dockerode";
import Redis from "ioredis";
import { promises as fs } from "fs";
import { join } from "path";

interface SessionData {
  userId: string;
  containerId?: string;
  containerName?: string;
  createdAt: string;
  workspaceRoot?: string;
}

@Injectable()
export class LanguageServerManager implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LanguageServerManager.name);
  private readonly docker: Docker;
  private readonly redis: Redis;
  private readonly containerMap: Map<string, string> = new Map();
  private cleanupInterval: NodeJS.Timeout | null = null;
  private readonly LSP_NETWORK_NAME = "backend";
  private readonly LSP_CONTAINER_PORT = 9000;

  constructor() {
    this.docker = new Docker({ socketPath: "/var/run/docker.sock" });
    this.redis = new Redis({
      host: process.env.REDIS_HOST || "localhost",
      port: parseInt(process.env.REDIS_PORT || "6379", 10),
    });
  }

  async onModuleInit() {
    this.logger.log("Language Server Manager initialized");
    this.startCleanupWorker();
    this.startSessionScanner();
  }

  async onModuleDestroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }

    await this.stopAllContainers();
    await this.redis.quit();
    this.logger.log("Language Server Manager destroyed");
  }

  private startSessionScanner() {
    setInterval(async () => {
      try {
        await this.scanAndCreateContainers();
      } catch (error) {
        this.logger.error("Error scanning sessions", error);
      }
    }, 5000);
  }

  private async scanAndCreateContainers() {
    const keys = await this.redis.keys("lsp:session:*");

    for (const key of keys) {
      const sessionId = key.replace("lsp:session:", "");

      if (this.containerMap.has(sessionId)) {
        continue;
      }

      const data = await this.redis.get(key);
      if (!data) {
        continue;
      }

      try {
        const sessionData: SessionData = JSON.parse(data);

        if (!sessionData.containerId) {
          await this.startContainer(sessionId, sessionData.userId);
        } else {
          this.containerMap.set(sessionId, sessionData.containerId);
        }
      } catch (error) {
        this.logger.error(
          `Error creating container for session ${sessionId}`,
          error
        );
      }
    }
  }

  private async startContainer(
    sessionId: string,
    userId: string
  ): Promise<void> {
    this.logger.log(`Starting container for session ${sessionId}`);

    const containerName = `lsp-${sessionId}`;
    const volumeName = process.env.CODE_FILES_VOLUME || "code-files";

    const containerBasePath = "/code-files";
    const containerWorkspace = `${containerBasePath}/${sessionId}`;

    const container = await this.docker.createContainer({
      Image: "dart-lsp:3.9.4",
      name: containerName,
      ExposedPorts: {
        [`${this.LSP_CONTAINER_PORT}/tcp`]: {},
      },
      HostConfig: {
        Memory: 512 * 1024 * 1024,
        NanoCpus: 1 * 1e9,
        NetworkMode: this.LSP_NETWORK_NAME,
        Binds: [`${volumeName}:${containerBasePath}:ro`],
      },
      WorkingDir: containerWorkspace,
    });

    await container.start();
    const containerId = container.id;

    this.containerMap.set(sessionId, containerId);

    const key = `lsp:session:${sessionId}`;
    const data = await this.redis.get(key);

    if (data) {
      const sessionData: SessionData = JSON.parse(data);
      sessionData.containerId = containerId;
      sessionData.containerName = containerName;
      sessionData.workspaceRoot = containerWorkspace;

      const ttl = await this.redis.ttl(key);
      if (ttl > 0) {
        await this.redis.setex(key, ttl, JSON.stringify(sessionData));
      }
    }

    this.logger.log(
      `Container ${containerId} (${containerName}) started for session ${sessionId} with volume ${volumeName}:${containerBasePath}, working dir: ${containerWorkspace}`
    );
  }

  private startCleanupWorker() {
    this.cleanupInterval = setInterval(async () => {
      try {
        await this.cleanupExpiredSessions();
      } catch (error) {
        this.logger.error("Error in cleanup worker", error);
      }
    }, 10000);
  }

  private async cleanupExpiredSessions() {
    const sessionsToClean: string[] = [];

    for (const [sessionId, containerId] of this.containerMap.entries()) {
      const key = `lsp:session:${sessionId}`;
      const exists = await this.redis.exists(key);

      if (!exists) {
        sessionsToClean.push(sessionId);
        await this.stopContainer(containerId, sessionId);
      }
    }

    sessionsToClean.forEach((sessionId) => this.containerMap.delete(sessionId));

    if (sessionsToClean.length > 0) {
      this.logger.log(`Cleaned up ${sessionsToClean.length} expired sessions`);
    }
  }

  private async stopContainer(containerId: string, sessionId: string) {
    try {
      const container = this.docker.getContainer(containerId);

      await container.stop({ t: 5 });
      await container.remove();

      this.logger.log(
        `Container ${containerId} stopped for session ${sessionId}`
      );

      // Clean up session files
      const basePath = process.env.CODE_FILES_PATH || "/code-files";
      const sessionDir = join(basePath, sessionId);

      try {
        await fs.rm(sessionDir, { recursive: true, force: true });
        this.logger.log(`Cleaned up files for session ${sessionId}`);
      } catch (error) {
        this.logger.error(
          `Error cleaning up files for session ${sessionId}`,
          error
        );
      }
    } catch (error) {
      this.logger.error(`Error stopping container ${containerId}`, error);
    }
  }

  private async stopAllContainers() {
    this.logger.log("Stopping all language server containers");

    const stopPromises = Array.from(this.containerMap.entries()).map(
      ([sessionId, containerId]) => this.stopContainer(containerId, sessionId)
    );

    await Promise.all(stopPromises);
    this.containerMap.clear();
  }
}
