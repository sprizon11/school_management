import { Module } from '@nestjs/common';
import { ChatModule } from '../chat/chat.module';
import { ParentController } from './parent.controller';

@Module({
  imports: [ChatModule],
  controllers: [ParentController],
})
export class ParentModule {}
