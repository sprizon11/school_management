import {
  ConflictException,
  Injectable,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSchoolDto } from './dto/create-school.dto';

@Injectable()
export class SchoolsService {
  constructor(private prisma: PrismaService) {}

  listPublic() {
    return this.prisma.school.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        code: true,
        city: true,
        address: true,
        logoUrl: true,
      },
    });
  }

  async createWithAdmin(dto: CreateSchoolDto) {
    const code = dto.code.trim().toLowerCase();
    const email = dto.adminEmail.trim().toLowerCase();

    const existingCode = await this.prisma.school.findUnique({
      where: { code },
    });
    if (existingCode) {
      throw new ConflictException('School code already exists');
    }

    const passwordHash = await bcrypt.hash(dto.adminPassword, 10);

    const school = await this.prisma.school.create({
      data: {
        name: dto.name.trim(),
        code,
        city: dto.city?.trim() || null,
        address: dto.address?.trim() || null,
        isActive: true,
        users: {
          create: {
            email,
            passwordHash,
            role: UserRole.ADMIN,
            fullName: dto.adminFullName.trim(),
          },
        },
      },
      select: {
        id: true,
        name: true,
        code: true,
        city: true,
        address: true,
        logoUrl: true,
        users: {
          where: { email },
          select: {
            id: true,
            email: true,
            fullName: true,
            role: true,
          },
        },
      },
    });

    const admin = school.users[0];
    return {
      school: {
        id: school.id,
        name: school.name,
        code: school.code,
        city: school.city,
        address: school.address,
        logoUrl: school.logoUrl,
      },
      admin: {
        id: admin.id,
        email: admin.email,
        fullName: admin.fullName,
        role: admin.role,
      },
    };
  }
}
