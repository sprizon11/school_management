import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { CreateClassDto } from './dto/create-class.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { CreateTeacherDto } from './dto/create-teacher.dto';
import { UpdateSchoolProfileDto } from './dto/update-school-profile.dto';
import { UpdateStudentDto } from './dto/update-student.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private admin: AdminService) {}

  @Get('dashboard/summary')
  dashboardSummary(@CurrentUser() user: { schoolId: string }) {
    return this.admin.dashboardSummary(user.schoolId);
  }

  @Get('profile')
  getProfile(@CurrentUser() user: { schoolId: string; userId: string }) {
    return this.admin.getProfile(user.schoolId, user.userId);
  }

  @Patch('profile')
  updateProfile(
    @CurrentUser() user: { schoolId: string; userId: string },
    @Body() dto: UpdateSchoolProfileDto,
  ) {
    return this.admin.updateProfile(user.schoolId, user.userId, dto);
  }

  @Get('announcements')
  listAnnouncements(@CurrentUser() user: { schoolId: string }) {
    return this.admin.listAnnouncements(user.schoolId);
  }

  @Post('announcements')
  createAnnouncement(
    @CurrentUser() user: { schoolId: string; userId: string },
    @Body() dto: CreateAnnouncementDto,
  ) {
    return this.admin.createAnnouncement(
      user.schoolId,
      user.userId,
      'Admin',
      dto,
    );
  }

  @Get('dashboard/attendance-chart')
  attendanceChart(@CurrentUser() user: { schoolId: string }) {
    return this.admin.attendanceChart(user.schoolId);
  }

  @Get('dashboard/fee-chart')
  feeChart(@CurrentUser() user: { schoolId: string }) {
    return this.admin.feeChart(user.schoolId);
  }

  @Get('students/stats')
  studentStats(@CurrentUser() user: { schoolId: string }) {
    return this.admin.studentStats(user.schoolId);
  }

  @Get('students/:id')
  getStudent(
    @CurrentUser() user: { schoolId: string },
    @Param('id') id: string,
  ) {
    return this.admin.getStudent(user.schoolId, id);
  }

  @Get('students')
  listStudents(
    @CurrentUser() user: { schoolId: string },
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
    @Query('classId') classId?: string,
  ) {
    return this.admin.listStudents(user.schoolId, {
      page: page ? +page : 1,
      limit: limit ? +limit : 10,
      search,
      classId,
    });
  }

  @Get('teachers/stats')
  teacherStats(@CurrentUser() user: { schoolId: string }) {
    return this.admin.teacherStats(user.schoolId);
  }

  @Get('teachers/:id')
  getTeacher(
    @CurrentUser() user: { schoolId: string },
    @Param('id') id: string,
  ) {
    return this.admin.getTeacher(user.schoolId, id);
  }

  @Delete('teachers/:id')
  deleteTeacher(
    @CurrentUser() user: { schoolId: string },
    @Param('id') id: string,
  ) {
    return this.admin.deleteTeacher(user.schoolId, id);
  }

  @Get('teachers')
  listTeachers(
    @CurrentUser() user: { schoolId: string },
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
  ) {
    return this.admin.listTeachers(user.schoolId, {
      page: page ? +page : 1,
      limit: limit ? +limit : 10,
      search,
    });
  }

  @Get('classes/stats')
  classStats(@CurrentUser() user: { schoolId: string }) {
    return this.admin.classStats(user.schoolId);
  }

  @Get('classes/stream-groups')
  streamGroups() {
    return this.admin.getSeniorStreamGroups();
  }

  @Get('classes/:id')
  getClass(
    @CurrentUser() user: { schoolId: string },
    @Param('id') id: string,
  ) {
    return this.admin.getClass(user.schoolId, id);
  }

  @Get('classes')
  listClasses(
    @CurrentUser() user: { schoolId: string },
    @Query('search') search?: string,
  ) {
    return this.admin.listClasses(user.schoolId, search);
  }

  @Post('students')
  createStudent(
    @CurrentUser() user: { schoolId: string },
    @Body() dto: CreateStudentDto,
  ) {
    return this.admin.createStudent(user.schoolId, dto);
  }

  @Patch('students/:id')
  updateStudent(
    @CurrentUser() user: { schoolId: string },
    @Param('id') id: string,
    @Body() dto: UpdateStudentDto,
  ) {
    return this.admin.updateStudent(user.schoolId, id, dto);
  }

  @Post('teachers')
  createTeacher(
    @CurrentUser() user: { schoolId: string },
    @Body() dto: CreateTeacherDto,
  ) {
    return this.admin.createTeacher(user.schoolId, dto);
  }

  @Post('classes')
  createClass(
    @CurrentUser() user: { schoolId: string },
    @Body() dto: CreateClassDto,
  ) {
    return this.admin.createClass(user.schoolId, dto);
  }

  @Get('attendance/overview')
  attendanceOverview(@CurrentUser() user: { schoolId: string }) {
    return this.admin.attendanceOverview(user.schoolId);
  }

  @Get('fees/overview')
  feesOverview(@CurrentUser() user: { schoolId: string }) {
    return this.admin.feesOverview(user.schoolId);
  }

  @Get('examinations/overview')
  examinationsOverview(@CurrentUser() user: { schoolId: string }) {
    return this.admin.examinationsOverview(user.schoolId);
  }

  @Get('timetable')
  timetable(@CurrentUser() user: { schoolId: string }) {
    return this.admin.timetable(user.schoolId);
  }

  @Get('reports/overview')
  reportsOverview(@CurrentUser() user: { schoolId: string }) {
    return this.admin.reportsOverview(user.schoolId);
  }
}
