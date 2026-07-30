import { Module } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { ParentController } from './parent.controller';
import { ParentService } from './parent.service';

@Module({
  imports: [ChatModule],
  controllers: [ParentController],
  providers: [ParentService],
})
export class ParentModule {}
