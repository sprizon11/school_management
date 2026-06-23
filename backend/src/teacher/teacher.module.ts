import { Module } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { TeacherController } from './teacher.controller';
import { TeacherService } from './teacher.service';

@Module({
  imports: [ChatModule],
  controllers: [TeacherController],
  providers: [TeacherService],
})
export class TeacherModule {}
