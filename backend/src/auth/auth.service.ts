import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

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
      include: {
        teacher: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (dto.expectedRole && user.role !== dto.expectedRole) {
      throw new BadRequestException(
        `This account is not a ${dto.expectedRole} account`,
      );
    }

    const payload = {
      sub: user.id,
      schoolId: user.schoolId,
      role: user.role,
      teacherId: user.teacher?.id,
    };

    return {
      accessToken: this.jwt.sign(payload),
      user: {
        id: user.id,
        schoolId: user.schoolId,
        schoolName: school.name,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        avatarUrl: user.avatarUrl,
        teacherId: user.teacher?.id,
      },
    };
  }

  async getProfile(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        teacher: true,
      },
    });
  }
}
