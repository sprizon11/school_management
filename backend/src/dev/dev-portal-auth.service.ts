import {
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { timingSafeEqual } from 'crypto';
import { DevPortalLoginDto } from './dto/dev-portal-login.dto';

@Injectable()
export class DevPortalAuthService {
  constructor(
    private config: ConfigService,
    private jwt: JwtService,
  ) {}

  private safeEqual(a: string, b: string) {
    const left = Buffer.from(a);
    const right = Buffer.from(b);
    if (left.length !== right.length) return false;
    return timingSafeEqual(left, right);
  }

  login(dto: DevPortalLoginDto) {
    const email = this.config.get<string>('DEV_PORTAL_EMAIL')?.trim().toLowerCase();
    const password = this.config.get<string>('DEV_PORTAL_PASSWORD');

    if (!email || !password) {
      throw new ServiceUnavailableException(
        'Developer portal login is not configured on this server',
      );
    }

    const providedEmail = dto.email.trim().toLowerCase();
    if (
      !this.safeEqual(providedEmail, email) ||
      !this.safeEqual(dto.password, password)
    ) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const accessToken = this.jwt.sign({
      sub: 'platform-dev',
      scope: 'platform_dev',
      email: providedEmail,
    });

    return {
      accessToken,
      user: { email: providedEmail, role: 'PLATFORM_DEV' },
    };
  }
}
