import {
  Injectable,
  NotFoundException,
  BadRequestException,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import Redis from 'ioredis';
import { ulid } from 'ulid';
import { promises as fs } from 'fs';
import { join } from 'path';

export interface SessionData {
  sessionId: string;
  createdAt: string;
  lastActivity: string;
  workspaceRoot: string;
  uploadedFiles: string[];
  status: 'pending' | 'ready' | 'terminated';
  containerId?: string;
}

@Injectable()
export class SessionsService implements OnModuleInit, OnModuleDestroy {
  private readonly redis: Redis;
  private readonly SESSION_TTL = 600; // 10 minutes
  private readonly MAX_SESSIONS = 4;
  private reconciliationInterval: NodeJS.Timeout | null = null;

  constructor() {
    this.redis = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379', 10),
    });
  }

  onModuleInit() {
    // Start reconciliation loop
    this.reconciliationInterval = setInterval(
      () => this.reconcileSessionCount(),
      30000,
    ); // Every 30 seconds
  }

  async onModuleDestroy() {
    if (this.reconciliationInterval) {
      clearInterval(this.reconciliationInterval);
    }
    await this.redis.quit();
  }

  private async reconcileSessionCount(): Promise<void> {
    try {
      const keys = await this.redis.keys('lsp:session:*');
      const actualCount = keys.length;
      await this.redis.set('session:active:count', actualCount);
    } catch (error) {
      console.error('Failed to reconcile session count:', error);
    }
  }

  private async getActiveSessionCount(): Promise<number> {
    const count = await this.redis.get('session:active:count');
    return count ? parseInt(count, 10) : 0;
  }

  async createSession(): Promise<{ sessionId: string }> {
    // Check capacity
    const activeCount = await this.getActiveSessionCount();
    if (activeCount >= this.MAX_SESSIONS) {
      throw new BadRequestException(
        'Maximum concurrent sessions (4) reached. Please try again later.',
      );
    }

    const sessionId = ulid();

    // Create directory
    const basePath = process.env.CODE_FILES_PATH || '/code-files';
    const sessionDir = join(basePath, sessionId);
    await fs.mkdir(sessionDir, { recursive: true });

    // Create initial main.dart file
    const mainDartPath = join(sessionDir, 'main.dart');
    const initialTemplate = [
      'void main() {',
      "  print('Hello, Dart!');",
      '}',
      '',
    ].join('\n');
    await fs.writeFile(mainDartPath, initialTemplate, 'utf-8');

    // Initialize session data
    const sessionData: SessionData = {
      sessionId,
      createdAt: new Date().toISOString(),
      lastActivity: new Date().toISOString(),
      workspaceRoot: `/code-files/${sessionId}`,
      uploadedFiles: ['main.dart'],
      status: 'pending',
    };

    // Store in Redis with TTL
    await this.redis.setex(
      `lsp:session:${sessionId}`,
      this.SESSION_TTL,
      JSON.stringify(sessionData),
    );

    // Increment counter
    await this.redis.incr('session:active:count');

    return { sessionId };
  }

  async updateFileFromBase64(
    sessionId: string,
    base64Content: string,
  ): Promise<{ filePath: string }> {
    // Validate session exists
    const sessionData = await this.getSession(sessionId);
    if (!sessionData) {
      throw new NotFoundException('Session not found');
    }

    // Decode base64
    let decodedContent: string;
    try {
      decodedContent = Buffer.from(base64Content, 'base64').toString('utf-8');
    } catch {
      throw new BadRequestException('Invalid base64 content');
    }

    // Validate file size (1MB)
    if (Buffer.byteLength(decodedContent, 'utf-8') > 1 * 1024 * 1024) {
      throw new BadRequestException('File size must be less than 1MB');
    }

    // Overwrite main.dart
    const basePath = process.env.CODE_FILES_PATH || '/code-files';
    const filePath = join(basePath, sessionId, 'main.dart');
    await fs.writeFile(filePath, decodedContent, 'utf-8');

    // Update session activity
    await this.updateLastActivity(sessionId);

    return { filePath: `/code-files/${sessionId}/main.dart` };
  }

  async renewSession(sessionId: string): Promise<void> {
    const key = `lsp:session:${sessionId}`;
    const data = await this.redis.get(key);

    if (!data) {
      throw new NotFoundException('Session not found');
    }

    const sessionData = JSON.parse(data) as SessionData;

    // Update lastActivity and reset TTL
    sessionData.lastActivity = new Date().toISOString();
    await this.redis.setex(key, this.SESSION_TTL, JSON.stringify(sessionData));
  }

  async closeSession(sessionId: string): Promise<void> {
    const sessionData = await this.getSession(sessionId);

    if (!sessionData) {
      throw new NotFoundException('Session not found');
    }

    // Set TTL to 1s for immediate cleanup
    await this.redis.expire(`lsp:session:${sessionId}`, 1);

    // Decrement counter
    await this.redis.decr('session:active:count');
  }

  async getSession(sessionId: string): Promise<SessionData | null> {
    const data = await this.redis.get(`lsp:session:${sessionId}`);
    return data ? (JSON.parse(data) as SessionData) : null;
  }

  async updateLastActivity(sessionId: string): Promise<void> {
    const key = `lsp:session:${sessionId}`;
    const data = await this.redis.get(key);

    if (!data) {
      return;
    }

    const sessionData = JSON.parse(data) as SessionData;
    sessionData.lastActivity = new Date().toISOString();

    await this.redis.setex(key, this.SESSION_TTL, JSON.stringify(sessionData));
  }

  async updateSessionContainer(
    sessionId: string,
    containerId: string,
  ): Promise<void> {
    const key = `lsp:session:${sessionId}`;
    const data = await this.redis.get(key);

    if (!data) {
      return;
    }

    const sessionData = JSON.parse(data) as SessionData;
    sessionData.containerId = containerId;

    const ttl = await this.redis.ttl(key);
    if (ttl > 0) {
      await this.redis.setex(key, ttl, JSON.stringify(sessionData));
    }
  }

  async getContainerId(sessionId: string): Promise<string | null> {
    const sessionData = await this.getSession(sessionId);
    return sessionData?.containerId || null;
  }
}
