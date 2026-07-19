import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UserRole } from '@prisma/client';
import { requireJwtSecret } from './jwt-secret';

export interface JwtPayload {
  sub: string;
  schoolId: string;
  role: UserRole;
  teacherId?: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: requireJwtSecret(),
    });
  }

  validate(payload: JwtPayload) {
    return {
      userId: payload.sub,
      schoolId: payload.schoolId,
      role: payload.role,
      teacherId: payload.teacherId,
    };
  }
}
