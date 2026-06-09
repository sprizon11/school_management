import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { timingSafeEqual } from 'crypto';
import { Request } from 'express';

@Injectable()
export class DevPortalGuard implements CanActivate {
  constructor(
    private config: ConfigService,
    private jwt: JwtService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();
    const auth = req.header('authorization');

    if (auth?.startsWith('Bearer ')) {
      const token = auth.slice(7);
      try {
        const payload = this.jwt.verify(token) as {
          scope?: string;
        };
        if (payload.scope === 'platform_dev') {
          return true;
        }
      } catch {
        throw new UnauthorizedException('Session expired — sign in again');
      }
    }

    const expected = this.config.get<string>('DEV_PLATFORM_KEY');
    if (expected?.trim()) {
      const provided = req.header('x-dev-key') ?? '';
      const expectedBuf = Buffer.from(expected);
      const providedBuf = Buffer.from(provided);
      if (
        providedBuf.length === expectedBuf.length &&
        timingSafeEqual(providedBuf, expectedBuf)
      ) {
        return true;
      }
    }

    throw new ForbiddenException('Developer access required');
  }
}
