import {
  Controller,
  Post,
  Param,
  HttpCode,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SessionsService } from '../sessions/sessions.service';
import { CreateSessionResponseDto } from './dto/create-session-response.dto';

@Controller('language-server')
export class LanguageServerController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('sessions')
  async createSession(): Promise<CreateSessionResponseDto> {
    return this.sessionsService.createSession();
  }

  @HttpCode(200)
  @Post('sessions/:sessionId/renew')
  async renewSession(@Param('sessionId') sessionId: string): Promise<void> {
    return this.sessionsService.renewSession(sessionId);
  }

  @Post('sessions/:sessionId/files')
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
              `File type not allowed. Only .dart files are allowed.`,
            ),
            false,
          );
        }
      },
    }),
  )
  async uploadFile(
    @Param('sessionId') sessionId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }

    const result = await this.sessionsService.updateFile(sessionId, file);

    return result;
  }
}
