import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ChatService } from '../chat/chat.service';
import { ParentService } from './parent.service';

// The global ValidationPipe uses `whitelist: true`, which strips any property
// without a class-validator decorator — an undecorated DTO arrives empty.
class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  body!: string;
}

@Controller('parent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PARENT)
export class ParentController {
  constructor(
    private chat: ChatService,
    private parent: ParentService,
  ) {}

  @Get('home')
  home(@CurrentUser() user: { userId: string }) {
    return this.parent.home(user.userId);
  }

  @Get('marks')
  marks(@CurrentUser() user: { userId: string }) {
    return this.parent.marks(user.userId);
  }

  @Get('chat/conversations')
  conversations(@CurrentUser() user: { userId: string; schoolId: string }) {
    return this.chat.listForParent(user.userId, user.schoolId);
  }

  @Get('chat/conversations/:id/messages')
  messages(
    @Param('id') id: string,
    @CurrentUser() user: { userId: string; role: UserRole },
  ) {
    return this.chat.messages(id, user.userId, user.role);
  }

  @Post('chat/conversations/:id/messages')
  send(
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
    @CurrentUser() user: { userId: string; role: UserRole },
  ) {
    return this.chat.send(id, user.userId, user.role, dto.body);
  }
}
