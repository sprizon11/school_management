import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'crypto';
import { Request } from 'express';

@Injectable()
export class DevKeyGuard implements CanActivate {
  constructor(private config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const expected = this.config.get<string>('DEV_PLATFORM_KEY');
    if (!expected?.trim()) {
      throw new ServiceUnavailableException(
        'Developer registration is not configured on this server',
      );
    }

    const req = context.switchToHttp().getRequest<Request>();
    const provided = req.header('x-dev-key') ?? '';
    const expectedBuf = Buffer.from(expected);
    const providedBuf = Buffer.from(provided);
    if (
      providedBuf.length !== expectedBuf.length ||
      !timingSafeEqual(providedBuf, expectedBuf)
    ) {
      throw new ForbiddenException('Invalid developer key');
    }

    return true;
  }
}
