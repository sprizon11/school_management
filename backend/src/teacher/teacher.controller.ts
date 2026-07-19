import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { UserRole } from '@prisma/client';
import { CreateStudentDto } from '../admin/dto/create-student.dto';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ChatService } from '../chat/chat.service';
import { TeacherService } from './teacher.service';

// NOTE: the global ValidationPipe runs with `whitelist: true`, which strips
// every property that carries no class-validator decorator. An undecorated DTO
// therefore arrives as `{}` and the handler sees undefined fields — so each
// property below must keep its decorator.

class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  body!: string;
}

class SaveScheduleDto {
  @IsInt()
  @Min(0)
  @Max(6)
  day!: number;

  // Slot contents are normalized by TeacherService.saveSchedule().
  @IsArray()
  slots!: Array<{
    start?: string;
    end?: string;
    subject?: string;
    classLabel?: string;
    room?: string;
  }>;
}

class CreateHomeworkDto {
  @IsString()
  @IsNotEmpty()
  classId!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsString()
  @IsNotEmpty()
  dueDate!: string;
}

class SaveAttendanceDto {
  @IsString()
  @IsNotEmpty()
  classId!: string;

  /** `YYYY-MM-DD`; defaults to today. */
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'date must be YYYY-MM-DD' })
  date?: string;

  /** Only the exceptions — everyone else is recorded PRESENT. */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  absentStudentIds?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  leaveStudentIds?: string[];
}

class SaveMarksDto {
  @IsString()
  @IsNotEmpty()
  classId!: string;

  @IsString()
  @IsNotEmpty()
  subjectName!: string;

  @IsString()
  @IsNotEmpty()
  termLabel!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxMarks?: number;

  // Entry contents are validated against the class roster in saveMarks().
  @IsArray()
  entries!: Array<{ studentId: string; marks: number; remarks?: string }>;
}

@Controller('teacher')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.TEACHER)
export class TeacherController {
  constructor(
    private teacher: TeacherService,
    private chat: ChatService,
  ) {}

  @Get('dashboard/summary')
  dashboard(@CurrentUser() user: { teacherId: string }) {
    return this.teacher.dashboard(user.teacherId);
  }

  @Get('dashboard/schedule')
  schedule(
    @CurrentUser() user: { teacherId: string },
    @Query('day') day?: string,
  ) {
    const parsed = day !== undefined ? Number(day) : undefined;
    return this.teacher.schedule(
      user.teacherId,
      parsed !== undefined && Number.isFinite(parsed) ? parsed : undefined,
    );
  }

  @Post('dashboard/schedule')
  saveSchedule(
    @CurrentUser() user: { teacherId: string },
    @Body() body: SaveScheduleDto,
  ) {
    return this.teacher.saveSchedule(
      user.teacherId,
      Number(body?.day),
      Array.isArray(body?.slots) ? body.slots : [],
    );
  }

  @Get('homework/upcoming')
  upcomingHomework(@CurrentUser() user: { teacherId: string }) {
    return this.teacher.upcomingHomework(user.teacherId);
  }

  @Get('classes')
  classes(@CurrentUser() user: { teacherId: string }) {
    return this.teacher.assignedClasses(user.teacherId);
  }

  @Get('classes/:classId')
  classDetail(
    @Param('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.classDetail(classId, user.teacherId);
  }

  @Get('classes/:classId/stats')
  classStats(
    @Param('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.classStats(classId, user.teacherId);
  }

  @Get('classes/:classId/students')
  classStudents(
    @Param('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
  ) {
    return this.teacher.classStudents(
      classId,
      user.teacherId,
      page ? +page : 1,
      limit ? +limit : 10,
      search,
    );
  }

  @Post('students')
  createStudent(
    @Body() dto: CreateStudentDto,
    @CurrentUser() user: { teacherId: string; schoolId: string },
  ) {
    return this.teacher.createStudent(user.teacherId, user.schoolId, dto);
  }

  @Get('classes/:classId/subjects')
  subjectOptions(
    @Param('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.subjectOptionsForClass(classId, user.teacherId);
  }

  @Post('homework')
  createHomework(
    @Body() dto: CreateHomeworkDto,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.createHomework(user.teacherId, dto);
  }

  @Get('attendance')
  attendanceRoster(
    @CurrentUser() user: { teacherId: string },
    @Query('classId') classId: string,
    @Query('date') date?: string,
  ) {
    return this.teacher.attendanceRoster(classId, user.teacherId, date);
  }

  @Post('attendance')
  saveAttendance(
    @Body() dto: SaveAttendanceDto,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.saveAttendance(user.teacherId, dto);
  }

  @Post('marks')
  saveMarks(
    @Body() dto: SaveMarksDto,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.saveMarks(user.teacherId, dto);
  }

  @Get('chat/conversations')
  chatConversations(
    @CurrentUser() user: { teacherId: string; schoolId: string },
  ) {
    return this.chat.listForTeacher(user.teacherId, user.schoolId);
  }

  @Get('chat/conversations/:id/messages')
  chatMessages(
    @Param('id') id: string,
    @CurrentUser() user: { userId: string; role: UserRole },
  ) {
    return this.chat.messages(id, user.userId, user.role);
  }

  @Post('chat/conversations/:id/messages')
  sendChatMessage(
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
    @CurrentUser() user: { userId: string; role: UserRole },
  ) {
    return this.chat.send(id, user.userId, user.role, dto.body);
  }

  @Get('reports/overview')
  reportsOverview(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.reportsOverview(classId, user.teacherId);
  }

  @Get('reports/performance-chart')
  performanceChart(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.performanceChart(classId, user.teacherId);
  }

  @Get('reports/attendance')
  attendanceReport(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.attendanceReport(classId, user.teacherId);
  }

  @Get('reports/marks')
  marksReport(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.marksReport(classId, user.teacherId);
  }

  @Get('reports/performance')
  performanceReport(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.performanceReport(classId, user.teacherId);
  }

  @Get('reports/assignments')
  assignmentsReport(
    @Query('classId') classId: string,
    @CurrentUser() user: { teacherId: string },
  ) {
    return this.teacher.assignmentsReport(classId, user.teacherId);
  }

  @Get('announcements')
  announcements(@CurrentUser() user: { schoolId: string }) {
    return this.teacher.listAnnouncements(user.schoolId);
  }

  @Get('notifications')
  notifications(@CurrentUser() user: { userId: string }) {
    return this.teacher.listNotifications(user.userId);
  }

  @Get('notifications/unread-count')
  unreadNotifications(@CurrentUser() user: { userId: string }) {
    return this.teacher.unreadNotificationCount(user.userId);
  }

  @Patch('notifications/:id/read')
  markNotificationRead(
    @Param('id') id: string,
    @CurrentUser() user: { userId: string },
  ) {
    return this.teacher.markNotificationRead(user.userId, id);
  }

  @Patch('notifications/read-all')
  markAllNotificationsRead(@CurrentUser() user: { userId: string }) {
    return this.teacher.markAllNotificationsRead(user.userId);
  }
}

