import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';
import { CreateClassDto } from './dto/create-class.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { CreateTeacherDto } from './dto/create-teacher.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private admin: AdminService) {}

  @Get('dashboard/summary')
  dashboardSummary() {
    return this.admin.dashboardSummary();
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

  @Get('classes')
  listClasses(@Query('search') search?: string) {
    return this.admin.listClasses(search);
  }

  @Post('students')
  createStudent(@Body() dto: CreateStudentDto) {
    return this.admin.createStudent(dto);
  }

  @Post('teachers')
  createTeacher(@Body() dto: CreateTeacherDto) {
    return this.admin.createTeacher(dto);
  }

  @Post('classes')
  createClass(@Body() dto: CreateClassDto) {
    return this.admin.createClass(dto);
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
