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

@Controller()
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post()
  async createSession() {
    return this.sessionsService.createSession();
  }

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
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    return this.sessionsService.updateFile(sessionId, file);
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
