import { TypeOrmModuleOptions } from '@nestjs/typeorm';

import { ExecutionJobStatusLog } from 'src/entities/execution-job-status-log.entity';
import { ExecutionJob } from 'src/entities/execution-job.entity';

export const typeOrmConfig: TypeOrmModuleOptions = {
  type: 'mysql',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306', 10) || 3306,
  username: process.env.DB_USERNAME || 'root',
  password: process.env.DB_PASSWORD || 'test',
  database: process.env.DB_DATABASE || 'Hello',
  entities: [ExecutionJob, ExecutionJobStatusLog],
  synchronize: false,
};
