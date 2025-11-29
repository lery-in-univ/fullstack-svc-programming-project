import { Module } from '@nestjs/common';
import { LanguageServerGateway } from './language-server.gateway';
import { SessionsModule } from '../sessions/sessions.module';

@Module({
  imports: [SessionsModule],
  providers: [LanguageServerGateway],
})
export class LanguageServerModule {}
