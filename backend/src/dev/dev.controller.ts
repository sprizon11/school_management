import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CreateSchoolDto } from '../schools/dto/create-school.dto';
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
}
