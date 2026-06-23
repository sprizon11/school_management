import { Controller, Get } from '@nestjs/common';
import { SchoolsService } from './schools.service';

@Controller('schools')
export class SchoolsController {
  constructor(private schools: SchoolsService) {}

  @Get('public')
  listPublic() {
    return this.schools.listPublic();
  }
}
