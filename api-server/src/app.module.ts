import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { typeOrmConfig } from './config/typeorm.config';
import { ExecutionModule } from './execution/execution.module';
import { SessionsModule } from './sessions/sessions.module';
import { LanguageServerModule } from './language-server/language-server.module';

@Module({
  imports: [
    TypeOrmModule.forRoot(typeOrmConfig),
    SessionsModule,
    ExecutionModule,
    LanguageServerModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
