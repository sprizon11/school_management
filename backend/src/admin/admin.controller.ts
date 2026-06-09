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
  attendanceChart() {
    return this.admin.attendanceChart();
  }

  @Get('dashboard/fee-chart')
  feeChart() {
    return this.admin.feeChart();
  }

  @Get('students/stats')
  studentStats() {
    return this.admin.studentStats();
  }

  @Get('students/:id')
  getStudent(@Param('id') id: string) {
    return this.admin.getStudent(id);
  }

  @Get('students')
  listStudents(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
    @Query('classId') classId?: string,
  ) {
    return this.admin.listStudents({
      page: page ? +page : 1,
      limit: limit ? +limit : 10,
      search,
      classId,
    });
  }

  @Get('teachers/stats')
  teacherStats() {
    return this.admin.teacherStats();
  }

  @Get('teachers/:id')
  getTeacher(@Param('id') id: string) {
    return this.admin.getTeacher(id);
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
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
  ) {
    return this.admin.listTeachers({
      page: page ? +page : 1,
      limit: limit ? +limit : 10,
      search,
    });
  }

  @Get('classes/stats')
  classStats() {
    return this.admin.classStats();
  }

  @Get('classes/stream-groups')
  streamGroups() {
    return this.admin.getSeniorStreamGroups();
  }

  @Get('classes/:id')
  getClass(@Param('id') id: string) {
    return this.admin.getClass(id);
  }

  @Get('classes')
  listClasses(
    @CurrentUser() user: { schoolId: string },
    @Query('search') search?: string,
  ) {
    return this.admin.listClasses(user.schoolId, search);
  }

  @Post('students')
  createStudent(@Body() dto: CreateStudentDto) {
    return this.admin.createStudent(dto);
  }

  @Patch('students/:id')
  updateStudent(@Param('id') id: string, @Body() dto: UpdateStudentDto) {
    return this.admin.updateStudent(id, dto);
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
  attendanceOverview() {
    return this.admin.attendanceOverview();
  }

  @Get('fees/overview')
  feesOverview() {
    return this.admin.feesOverview();
  }

  @Get('examinations/overview')
  examinationsOverview() {
    return this.admin.examinationsOverview();
  }

  @Get('timetable')
  timetable() {
    return this.admin.timetable();
  }

  @Get('reports/overview')
  reportsOverview() {
    return this.admin.reportsOverview();
  }
}
