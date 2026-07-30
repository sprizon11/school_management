import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import type { Parent, School, Teacher, User } from '@prisma/client';
import { OAuth2Client } from 'google-auth-library';
import { PrismaService } from '../prisma/prisma.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { generateRefreshToken, hashToken } from './token.util';

type UserWithRelations = User & {
  teacher: Teacher | null;
  parent: Parent | null;
};

@Injectable()
export class AuthService {
  // Brute-force lockout tuning.
  private static readonly MAX_FAILED = 5;
  private static readonly LOCK_MINUTES = 15;
  // Refresh tokens outlive the short access token so users aren't asked to
  // re-enter credentials often, while a stolen access token dies in minutes.
  private static readonly REFRESH_DAYS = 30;

  private readonly googleClient = new OAuth2Client();

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  // Accepts the web, Android, and iOS OAuth client IDs (comma-separated) as
  // valid audiences for a Google ID token.
  private static googleAudiences(): string[] {
    return (process.env.GOOGLE_CLIENT_IDS || process.env.GOOGLE_CLIENT_ID || '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  async login(dto: LoginDto) {
    const school = await this.prisma.school.findUnique({
      where: { id: dto.schoolId },
    });
    if (!school) {
      throw new UnauthorizedException('School not found');
    }
    if (!school.isActive) {
      throw new UnauthorizedException('Service has been stopped for this school');
    }

    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: {
        schoolId: dto.schoolId,
        OR: [{ email: identifier }, { phone: dto.identifier.trim() }],
      },
      include: { teacher: true, parent: true },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Lockout gate — checked before the password so a locked account can't be
    // probed, and the counter isn't driven up further while locked.
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw new UnauthorizedException(
        'Account temporarily locked after repeated failed logins. Try again later.',
      );
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      await this.registerFailedLogin(user.id, user.failedLoginCount);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (dto.expectedRole && user.role !== dto.expectedRole) {
      throw new BadRequestException(
        `This account is not a ${dto.expectedRole} account`,
      );
    }

    // Successful login clears any accumulated failures / lock.
    if (user.failedLoginCount > 0 || user.lockedUntil) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { failedLoginCount: 0, lockedUntil: null },
      });
    }

    return this.issueSession(user, school);
  }

  /**
   * Sign in with a Google ID token. This is invite-only: it authenticates an
   * account the school already provisioned (matched by verified email within
   * the school), never a self-registration. The Google identity is linked on
   * first use so a later email change can't hijack the account.
   */
  async loginWithGoogle(schoolId: string, idToken: string) {
    const audience = AuthService.googleAudiences();
    if (audience.length === 0) {
      throw new BadRequestException('Google sign-in is not configured');
    }

    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
    });
    if (!school) throw new UnauthorizedException('School not found');
    if (!school.isActive) {
      throw new UnauthorizedException('Service has been stopped for this school');
    }

    let email: string | undefined;
    let sub: string | undefined;
    try {
      const ticket = await this.googleClient.verifyIdToken({ idToken, audience });
      const payload = ticket.getPayload();
      if (payload?.email_verified) {
        email = payload.email?.trim().toLowerCase();
        sub = payload.sub;
      }
    } catch {
      throw new UnauthorizedException('Could not verify Google sign-in');
    }
    if (!email || !sub) {
      throw new UnauthorizedException('Google account has no verified email');
    }

    const user = await this.prisma.user.findFirst({
      where: { schoolId, email },
      include: { teacher: true, parent: true },
    });
    if (!user) {
      throw new UnauthorizedException(
        'No account for this Google address at this school',
      );
    }

    if (!user.googleId) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { googleId: sub },
      });
    } else if (user.googleId !== sub) {
      throw new UnauthorizedException(
        'This account is linked to a different Google identity',
      );
    }

    // A verified Google sign-in also clears any brute-force lock.
    if (user.failedLoginCount > 0 || user.lockedUntil) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { failedLoginCount: 0, lockedUntil: null },
      });
    }

    return this.issueSession(user, school);
  }

  /** Exchange a valid refresh token for a new session (token rotation). */
  async refresh(rawToken: string) {
    if (!rawToken) throw new UnauthorizedException('Missing refresh token');
    const record = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashToken(rawToken) },
      include: {
        user: {
          include: { teacher: true, parent: true, school: true },
        },
      },
    });
    if (!record || record.revokedAt || record.expiresAt < new Date()) {
      throw new UnauthorizedException('Session expired, please sign in again');
    }
    if (!record.user.school.isActive) {
      throw new UnauthorizedException('Service has been stopped for this school');
    }

    // Rotate: the presented token is single-use.
    await this.prisma.refreshToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    });

    return this.issueSession(record.user, record.user.school);
  }

  /** Revoke a refresh token (sign out on this device). */
  async logout(rawToken?: string) {
    if (rawToken) {
      await this.prisma.refreshToken.updateMany({
        where: { tokenHash: hashToken(rawToken), revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return { ok: true };
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { teacher: true, parent: true, school: true },
    });
    if (!user) throw new UnauthorizedException();

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) {
      throw new BadRequestException('Current password is incorrect');
    }
    if (dto.newPassword === dto.currentPassword) {
      throw new BadRequestException(
        'New password must be different from the current one',
      );
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash, mustChangePassword: false },
    });
    // Reflect the cleared flag in the in-memory user, so the session we issue
    // below doesn't echo the stale `true` and bounce the client back here.
    user.mustChangePassword = false;

    // A password change invalidates every existing session; hand back a fresh
    // one so the current device stays signed in with new tokens.
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });

    return this.issueSession(user, user.school);
  }

  async getProfile(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        teacher: true,
      },
    });
  }

  // ---- internals ----

  private async registerFailedLogin(userId: string, current: number) {
    const next = current + 1;
    const locked = next >= AuthService.MAX_FAILED;
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        // Reset the counter when locking so a fresh window opens once the lock
        // expires, rather than locking again on the very next failure.
        failedLoginCount: locked ? 0 : next,
        lockedUntil: locked
          ? new Date(Date.now() + AuthService.LOCK_MINUTES * 60_000)
          : undefined,
      },
    });
  }

  private async createRefreshToken(userId: string): Promise<string> {
    const token = generateRefreshToken();
    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: hashToken(token),
        expiresAt: new Date(
          Date.now() + AuthService.REFRESH_DAYS * 86_400_000,
        ),
      },
    });
    return token;
  }

  /** Build the access token, a fresh refresh token, and the client user shape. */
  private async issueSession(user: UserWithRelations, school: School) {
    const payload = {
      sub: user.id,
      schoolId: user.schoolId,
      role: user.role,
      teacherId: user.teacher?.id,
      parentId: user.parent?.id,
    };

    const accessToken = this.jwt.sign(payload);
    const refreshToken = await this.createRefreshToken(user.id);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        schoolId: user.schoolId,
        schoolName: school.name,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        avatarUrl: user.avatarUrl,
        teacherId: user.teacher?.id,
        parentId: user.parent?.id,
        mustChangePassword: user.mustChangePassword,
      },
    };
  }
}
