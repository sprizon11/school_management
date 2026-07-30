import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { AdminModule } from './admin/admin.module';
import { AutomationModule } from './automation/automation.module';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { DevModule } from './dev/dev.module';
import { SchoolsModule } from './schools/schools.module';
import { ParentModule } from './parent/parent.module';
import { TeacherModule } from './teacher/teacher.module';

@Module({
  controllers: [HealthController],
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    // Configured globally but only enforced where a ThrottlerGuard is applied
    // (the auth endpoints). A global guard would rate-limit whole schools that
    // share one NAT IP; brute-force is instead bounded per-account by lockout.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 20 }]),
    PrismaModule,
    AuthModule,
    DevModule,
    SchoolsModule,
    AdminModule,
    AutomationModule,
    TeacherModule,
    ParentModule,
  ],
})
export class AppModule {}
