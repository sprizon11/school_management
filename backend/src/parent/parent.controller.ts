import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ChatService } from '../chat/chat.service';

class SendMessageDto {
  body!: string;
}

@Controller('parent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PARENT)
export class ParentController {
  constructor(private chat: ChatService) {}

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
