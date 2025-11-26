import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { typeOrmConfig } from './config/typeorm.config';
import { ExecutionModule } from './execution/execution.module';
import { UserModule } from './user/user.module';
import { UtilModule } from './util/util.module';
import { LanguageServerModule } from './language-server/language-server.module';
import { SessionsModule } from './sessions/sessions.module';

@Module({
  imports: [
    TypeOrmModule.forRoot(typeOrmConfig),
    UtilModule,
    AuthModule,
    UserModule,
    SessionsModule,
    ExecutionModule,
    LanguageServerModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
