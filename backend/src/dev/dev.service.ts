import { Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SchoolsService } from '../schools/schools.service';
import { CreateSchoolDto } from '../schools/dto/create-school.dto';

@Injectable()
export class DevService {
  constructor(
    private prisma: PrismaService,
    private schools: SchoolsService,
  ) {}

  private async schoolStats(schoolId: string) {
    const [students, teachers, admins, parents, classes] = await Promise.all([
      this.prisma.student.count({
        where: { class: { schoolId } },
      }),
      this.prisma.user.count({
        where: { schoolId, role: UserRole.TEACHER },
      }),
      this.prisma.user.count({
        where: { schoolId, role: UserRole.ADMIN },
      }),
      this.prisma.user.count({
        where: { schoolId, role: UserRole.PARENT },
      }),
      this.prisma.class.count({ where: { schoolId } }),
    ]);

    return { students, teachers, admins, parents, classes };
  }

  async platformOverview() {
    const schools = await this.prisma.school.findMany({
      select: { id: true, isActive: true },
    });

    const schoolIds = schools.map((s) => s.id);
    const [students, teachers, admins, parents, classes] = await Promise.all([
      schoolIds.length === 0
        ? 0
        : this.prisma.student.count({
            where: { class: { schoolId: { in: schoolIds } } },
          }),
      schoolIds.length === 0
        ? 0
        : this.prisma.user.count({
            where: { schoolId: { in: schoolIds }, role: UserRole.TEACHER },
          }),
      schoolIds.length === 0
        ? 0
        : this.prisma.user.count({
            where: { schoolId: { in: schoolIds }, role: UserRole.ADMIN },
          }),
      schoolIds.length === 0
        ? 0
        : this.prisma.user.count({
            where: { schoolId: { in: schoolIds }, role: UserRole.PARENT },
          }),
      schoolIds.length === 0
        ? 0
        : this.prisma.class.count({
            where: { schoolId: { in: schoolIds } },
          }),
    ]);

    return {
      schools: {
        total: schools.length,
        active: schools.filter((s) => s.isActive).length,
        inactive: schools.filter((s) => !s.isActive).length,
      },
      students,
      teachers,
      admins,
      parents,
      classes,
    };
  }

  async listSchools() {
    const schools = await this.prisma.school.findMany({
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        code: true,
        city: true,
        address: true,
        logoUrl: true,
        isActive: true,
        createdAt: true,
      },
    });

    return Promise.all(
      schools.map(async (school) => ({
        ...school,
        stats: await this.schoolStats(school.id),
      })),
    );
  }

  async getSchool(id: string) {
    const school = await this.prisma.school.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        code: true,
        city: true,
        address: true,
        logoUrl: true,
        isActive: true,
        createdAt: true,
      },
    });

    if (!school) {
      throw new NotFoundException('School not found');
    }

    const stats = await this.schoolStats(id);

    const [admins, classes] = await Promise.all([
      this.prisma.user.findMany({
        where: { schoolId: id, role: UserRole.ADMIN },
        orderBy: { fullName: 'asc' },
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          createdAt: true,
        },
      }),
      this.prisma.class.findMany({
        where: { schoolId: id },
        orderBy: [{ grade: 'asc' }, { section: 'asc' }],
        select: {
          id: true,
          name: true,
          grade: true,
          section: true,
          academicYear: true,
          _count: { select: { students: true } },
        },
      }),
    ]);

    return {
      school,
      stats,
      admins,
      classes: classes.map((c) => ({
        id: c.id,
        name: c.name,
        grade: c.grade,
        section: c.section,
        academicYear: c.academicYear,
        students: c._count.students,
      })),
    };
  }

  createSchool(dto: CreateSchoolDto) {
    return this.schools.createWithAdmin(dto);
  }
}
