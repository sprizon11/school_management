import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health.controller';
import { PrismaModule } from './prisma/prisma.module';
import { DevModule } from './dev/dev.module';
import { SchoolsModule } from './schools/schools.module';
import { TeacherModule } from './teacher/teacher.module';

@Module({
  controllers: [HealthController],
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    DevModule,
    SchoolsModule,
    AdminModule,
    TeacherModule,
  ],
})
export class AppModule {}
