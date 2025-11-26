import {
  Controller,
  Post,
  Put,
  Delete,
  Param,
  UseInterceptors,
  UploadedFile,
  HttpCode,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SessionsService } from './sessions.service';
import { Auth } from '../auth/auth.decorator';
import { GetRequester } from '../auth/requester.decorator';
import type { Requester } from '../auth/requester.decorator';

@Controller()
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Auth()
  @Post()
  async createSession(@GetRequester() requester: Requester) {
    return this.sessionsService.createSession(requester.userId);
  }

  @Auth()
  @Put('/sessions/:sessionId/files/main.dart')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 1 * 1024 * 1024, // 1MB
      },
      fileFilter: (_req, file, callback) => {
        const allowedExtensions = ['.dart'];
        const ext = file.originalname.substring(
          file.originalname.lastIndexOf('.'),
        );
        if (allowedExtensions.includes(ext)) {
          callback(null, true);
        } else {
          callback(
            new BadRequestException(
              'File type not allowed. Only .dart files are allowed.',
            ),
            false,
          );
        }
      },
    }),
  )
  async updateFile(
    @Param('sessionId') sessionId: string,
    @GetRequester() requester: Requester,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    return this.sessionsService.updateFile(sessionId, requester.userId, file);
  }

  @Auth()
  @HttpCode(200)
  @Post('/sessions/:sessionId/renew')
  async renewSession(
    @Param('sessionId') sessionId: string,
    @GetRequester() requester: Requester,
  ) {
    await this.sessionsService.renewSession(sessionId, requester.userId);
    return { message: 'Session renewed successfully' };
  }

  @Auth()
  @HttpCode(204)
  @Delete('/sessions/:sessionId')
  async closeSession(
    @Param('sessionId') sessionId: string,
    @GetRequester() requester: Requester,
  ) {
    await this.sessionsService.closeSession(sessionId, requester.userId);
  }
}
