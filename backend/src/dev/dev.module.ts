import { Module } from '@nestjs/common';
import { DevKeyGuard } from '../schools/dev-key.guard';
import { SchoolsModule } from '../schools/schools.module';
import { DevController } from './dev.controller';
import { DevService } from './dev.service';

@Module({
  imports: [SchoolsModule],
  controllers: [DevController],
  providers: [DevService, DevKeyGuard],
})
export class DevModule {}
