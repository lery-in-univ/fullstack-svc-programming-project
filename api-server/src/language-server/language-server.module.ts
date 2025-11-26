import { Module } from '@nestjs/common';
import { LanguageServerController } from './language-server.controller';
import { LanguageServerGateway } from './language-server.gateway';
import { SessionsModule } from '../sessions/sessions.module';

@Module({
  imports: [SessionsModule],
  controllers: [LanguageServerController],
  providers: [LanguageServerGateway],
})
export class LanguageServerModule {}
