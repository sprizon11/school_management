import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ParentService } from './parent.service';

@Controller('parent')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PARENT)
export class ParentController {
  constructor(private parent: ParentService) {}

  private async resolveStudent(
    user: { parentId: string },
    studentId?: string,
  ) {
    const children = await this.parent.children(user.parentId);
    const id = studentId ?? children[0]?.id;
    if (!id) throw new Error('No child linked');
    await this.parent.assertStudentAccess(user.parentId, id);
    return id;
  }

  @Get('children')
  children(@CurrentUser() user: { parentId: string }) {
    return this.parent.children(user.parentId);
  }

  @Get('dashboard/summary')
  async dashboard(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.dashboardSummary(id);
  }

  @Get('announcements')
  announcements() {
    return this.parent.announcements();
  }

  @Get('events')
  events() {
    return this.parent.events();
  }

  @Get('performance/by-subject')
  async performance(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.performanceBySubject(id);
  }

  @Get('attendance/summary')
  async attendanceSummary(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.attendanceSummary(id);
  }

  @Get('attendance/calendar')
  async attendanceCalendar(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
    @Query('year') year?: string,
    @Query('month') month?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    const y = year ? +year : new Date().getFullYear();
    const m = month ? +month : new Date().getMonth() + 1;
    return this.parent.attendanceCalendar(id, y, m);
  }

  @Get('attendance/recent')
  async attendanceRecent(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.attendanceRecent(id);
  }

  @Get('attendance/trend')
  async attendanceTrend(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.attendanceTrend(id);
  }

  @Get('results/summary')
  async resultsSummary(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.resultsSummary(id);
  }

  @Get('results/marks')
  async resultsMarks(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.resultsMarks(id);
  }

  @Get('results/grade-history')
  async gradeHistory(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.gradeHistory(id);
  }

  @Get('results/remarks')
  async remarks(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.teacherRemarks(id);
  }

  @Get('fees/summary')
  async feesSummary(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.feesSummary(id);
  }

  @Get('fees/installments')
  async feesInstallments(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.feesInstallments(id);
  }

  @Get('fees/payments')
  async feesPayments(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.feesPayments(id);
  }

  @Get('fees/breakdown')
  async feesBreakdown(
    @CurrentUser() user: { parentId: string },
    @Query('studentId') studentId?: string,
  ) {
    const id = await this.resolveStudent(user, studentId);
    return this.parent.feesBreakdown(id);
  }

  @Get('profile')
  profile(@CurrentUser() user: { parentId: string }) {
    return this.parent.profile(user.parentId);
  }
}
