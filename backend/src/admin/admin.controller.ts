import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';

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
}
