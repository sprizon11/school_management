import {
  Controller,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { TeacherService } from './teacher.service';

@Controller('teacher')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.TEACHER)
export class TeacherController {
  constructor(private teacher: TeacherService) {}

  @Get('dashboard/summary')
  dashboard(@CurrentUser() user: { teacherId: string }) {
    return this.teacher.dashboard(user.teacherId);
  }

  @Get('dashboard/schedule')
  schedule(@CurrentUser() user: { teacherId: string }) {
    return this.teacher.schedule(user.teacherId);
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
  classStats(@Param('classId') classId: string) {
    return this.teacher.classStats(classId);
  }

  @Get('classes/:classId/students')
  classStudents(
    @Param('classId') classId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
  ) {
    return this.teacher.classStudents(
      classId,
      page ? +page : 1,
      limit ? +limit : 10,
      search,
    );
  }

  @Get('reports/overview')
  reportsOverview(@Query('classId') classId: string) {
    return this.teacher.reportsOverview(classId);
  }

  @Get('reports/performance-chart')
  performanceChart(@Query('classId') classId: string) {
    return this.teacher.performanceChart(classId);
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
