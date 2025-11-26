import { Module } from '@nestjs/common';
import { LanguageServerController } from './language-server.controller';
import { LanguageServerService } from './language-server.service';
import { LanguageServerGateway } from './language-server.gateway';
import { UtilModule } from '../util/util.module';
import { SessionsModule } from '../sessions/sessions.module';

@Module({
  imports: [UtilModule, SessionsModule],
  controllers: [LanguageServerController],
  providers: [LanguageServerService, LanguageServerGateway],
  exports: [LanguageServerService],
})
export class LanguageServerModule {}
