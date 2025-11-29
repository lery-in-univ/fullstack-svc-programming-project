import {
  Controller,
  Post,
  Put,
  Delete,
  Param,
  Body,
  HttpCode,
  BadRequestException,
} from '@nestjs/common';
import { SessionsService } from './sessions.service';

@Controller()
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('sessions')
  async createSession() {
    const sessionData = await this.sessionsService.createSession();

    return {
      ...sessionData,
      websocket: {
        url: process.env.WEBSOCKET_URL || 'http://localhost:3000',
        namespace: '/lsp',
        path: '/socket.io/',
      },
    };
  }

  @Put('/sessions/:sessionId/files')
  async updateFile(
    @Param('sessionId') sessionId: string,
    @Body() body: { content: string },
  ) {
    if (!body.content) {
      throw new BadRequestException('Content is required');
    }
    return this.sessionsService.updateFileFromBase64(sessionId, body.content);
  }

  @HttpCode(200)
  @Post('/sessions/:sessionId/renew')
  async renewSession(@Param('sessionId') sessionId: string) {
    await this.sessionsService.renewSession(sessionId);
    return { message: 'Session renewed successfully' };
  }

  @HttpCode(204)
  @Delete('/sessions/:sessionId')
  async closeSession(@Param('sessionId') sessionId: string) {
    await this.sessionsService.closeSession(sessionId);
  }
}
