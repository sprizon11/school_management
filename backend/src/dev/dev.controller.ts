import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CreateSchoolDto } from '../schools/dto/create-school.dto';
import { DeleteSchoolDto } from './dto/delete-school.dto';
import { ResetAdminPasswordDto } from './dto/reset-admin-password.dto';
import { UpdateSchoolDto } from './dto/update-school.dto';
import { DevPortalGuard } from './dev-portal.guard';
import { DevService } from './dev.service';

@Controller('dev')
@UseGuards(DevPortalGuard)
export class DevController {
  constructor(private dev: DevService) {}

  @Get('overview')
  overview() {
    return this.dev.platformOverview();
  }

  @Get('schools')
  listSchools() {
    return this.dev.listSchools();
  }

  @Get('schools/:id')
  getSchool(@Param('id') id: string) {
    return this.dev.getSchool(id);
  }

  @Post('schools')
  createSchool(@Body() dto: CreateSchoolDto) {
    return this.dev.createSchool(dto);
  }

  @Patch('schools/:id')
  updateSchool(@Param('id') id: string, @Body() dto: UpdateSchoolDto) {
    return this.dev.updateSchool(id, dto);
  }

  @Patch('schools/:schoolId/admins/:adminId/password')
  resetAdminPassword(
    @Param('schoolId') schoolId: string,
    @Param('adminId') adminId: string,
    @Body() dto: ResetAdminPasswordDto,
  ) {
    return this.dev.resetAdminPassword(schoolId, adminId, dto.newPassword);
  }

  @Delete('schools/:id')
  deleteSchool(@Param('id') id: string, @Body() dto: DeleteSchoolDto) {
    return this.dev.deleteSchool(id, dto.confirmCode);
  }

  @Post('clear-demo')
  clearDemo() {
    return this.dev.clearDemoData();
  }

  @Post('clear-all-classes-teachers')
  clearAllClassesAndTeachers() {
    return this.dev.clearAllClassesAndTeachers();
  }
}
