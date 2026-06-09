import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { SchoolsModule } from '../schools/schools.module';
import { DevAuthController } from './dev-auth.controller';
import { DevPortalAuthService } from './dev-portal-auth.service';
import { DevPortalGuard } from './dev-portal.guard';
import { DevController } from './dev.controller';
import { DevService } from './dev.service';

@Module({
  imports: [AuthModule, SchoolsModule],
  controllers: [DevAuthController, DevController],
  providers: [DevService, DevPortalAuthService, DevPortalGuard],
})
export class DevModule {}
