import { Body, Controller, Post } from '@nestjs/common';
import { DevPortalAuthService } from './dev-portal-auth.service';
import { DevPortalLoginDto } from './dto/dev-portal-login.dto';

@Controller('dev')
export class DevAuthController {
  constructor(private auth: DevPortalAuthService) {}

  @Post('auth/login')
  login(@Body() dto: DevPortalLoginDto) {
    return this.auth.login(dto);
  }
}
