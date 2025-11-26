import { Entity, Column, PrimaryColumn, OneToMany } from 'typeorm';
import { ExecutionJobStatusLog } from './execution-job-status-log.entity';

@Entity('ExecutionJob')
export class ExecutionJob {
  @PrimaryColumn({ type: 'varchar', length: 50 })
  id: string;

  @Column({ type: 'varchar', length: 50 })
  sessionId: string;

  @Column({ type: 'varchar', length: 200 })
  filePath: string;

  @Column({ type: 'datetime', precision: 3 })
  createdAt: Date;

  @Column({ type: 'text', nullable: true })
  output: string | null;

  @Column({ type: 'text', nullable: true })
  error: string | null;

  @Column({ type: 'int', nullable: true })
  exitCode: number | null;

  @Column({ type: 'datetime', precision: 3, nullable: true })
  completedAt: Date | null;

  @OneToMany(() => ExecutionJobStatusLog, (status) => status.job)
  statuses: ExecutionJobStatusLog[];
}
