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

  private guardianWhere(schoolIds: string[]) {
    return {
      class: { schoolId: { in: schoolIds } },
      OR: [{ fatherName: { not: null } }, { motherName: { not: null } }],
    };
  }

  private async countGuardianProfiles(schoolIds: string[]) {
    if (schoolIds.length === 0) return 0;
    return this.prisma.student.count({
      where: this.guardianWhere(schoolIds),
    });
  }

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
      this.prisma.student.count({
        where: this.guardianWhere([schoolId]),
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
      this.countGuardianProfiles(schoolIds),
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

    const [admins, classes, students] = await Promise.all([
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
      this.prisma.student.findMany({
        where: { class: { schoolId: id } },
        orderBy: { fullName: 'asc' },
        select: {
          id: true,
          fullName: true,
          rollNumber: true,
          fatherName: true,
          fatherPhone: true,
          fatherOccupation: true,
          motherName: true,
          motherPhone: true,
          motherOccupation: true,
          parentAddress: true,
          emergencyContact: true,
          emergencyPhone: true,
          class: { select: { name: true, grade: true, section: true } },
        },
      }),
    ]);

    const guardians = students
      .filter((s) => s.fatherName?.trim() || s.motherName?.trim())
      .map((s) => ({
        studentId: s.id,
        studentName: s.fullName,
        rollNumber: s.rollNumber,
        classLabel: `${s.class.name} · ${s.class.grade}${s.class.section}`,
        fatherName: s.fatherName,
        fatherPhone: s.fatherPhone,
        fatherOccupation: s.fatherOccupation,
        motherName: s.motherName,
        motherPhone: s.motherPhone,
        motherOccupation: s.motherOccupation,
        address: s.parentAddress,
        emergencyContact: s.emergencyContact,
        emergencyPhone: s.emergencyPhone,
      }));

    return {
      school,
      stats,
      admins,
      guardians,
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

  private isSeedStudentCode(code: string) {
    if (code === 'ARU24001') return true;
    return /^STU\d{5}$/.test(code);
  }

  private isSeedTeacherEmail(email: string) {
    return (
      email.endsWith('@seed.demo') ||
      email === 'teacher@school.demo' ||
      email === 'priya@school.demo'
    );
  }

  private isSeedTeacherCode(code: string) {
    return /^TCH24\d{3}$/.test(code);
  }

  private isDemoAdminEmail(email: string) {
    return email === 'admin2@school.demo' || email.endsWith('@seed.demo');
  }

  async clearDemoData() {
    const allStudents = await this.prisma.student.findMany({
      select: { id: true, studentCode: true, email: true },
    });

    const demoStudentIds = allStudents
      .filter(
        (s) =>
          this.isSeedStudentCode(s.studentCode) ||
          (s.email?.includes('@seed.demo') ?? false) ||
          (s.email?.includes('@student.demo') ?? false),
      )
      .map((s) => s.id);

    if (demoStudentIds.length > 0) {
      const assignments = await this.prisma.feeAssignment.findMany({
        where: { studentId: { in: demoStudentIds } },
        select: { id: true },
      });
      const assignmentIds = assignments.map((a) => a.id);

      if (assignmentIds.length > 0) {
        const installments = await this.prisma.feeInstallment.findMany({
          where: { assignmentId: { in: assignmentIds } },
          select: { id: true },
        });
        const installmentIds = installments.map((i) => i.id);

        if (installmentIds.length > 0) {
          await this.prisma.feePayment.deleteMany({
            where: { installmentId: { in: installmentIds } },
          });
        }
        await this.prisma.feeInstallment.deleteMany({
          where: { assignmentId: { in: assignmentIds } },
        });
        await this.prisma.feeAssignment.deleteMany({
          where: { id: { in: assignmentIds } },
        });
      }

      await this.prisma.student.deleteMany({
        where: { id: { in: demoStudentIds } },
      });
    }

    const teacherUsers = await this.prisma.user.findMany({
      where: { role: UserRole.TEACHER },
      select: { id: true },
    });
    const teacherUserIds = teacherUsers.map((u) => u.id);

    if (teacherUserIds.length > 0) {
      const teacherProfiles = await this.prisma.teacher.findMany({
        where: { userId: { in: teacherUserIds } },
        select: { id: true },
      });
      const teacherIds = teacherProfiles.map((t) => t.id);

      if (teacherIds.length > 0) {
        await this.prisma.homework.deleteMany({
          where: { teacherId: { in: teacherIds } },
        });
        await this.prisma.mark.updateMany({
          where: { teacherId: { in: teacherIds } },
          data: { teacherId: null },
        });
        await this.prisma.class.updateMany({
          where: { classTeacherId: { in: teacherIds } },
          data: { classTeacherId: null },
        });
      }

      await this.prisma.user.deleteMany({
        where: { id: { in: teacherUserIds } },
      });
    }

    const demoAdmins = await this.prisma.user.findMany({
      where: { role: UserRole.ADMIN },
      select: { id: true, email: true },
    });
    const demoAdminIds = demoAdmins
      .filter((u) => this.isDemoAdminEmail(u.email))
      .map((u) => u.id);
    if (demoAdminIds.length > 0) {
      await this.prisma.user.deleteMany({
        where: { id: { in: demoAdminIds } },
      });
    }

    const remainingStudents = await this.prisma.student.count();
    let classesRemoved = 0;
    if (remainingStudents === 0) {
      await this.prisma.homework.deleteMany();
      await this.prisma.class.updateMany({ data: { classTeacherId: null } });
      const result = await this.prisma.class.deleteMany();
      classesRemoved = result.count;
    }

    const orphanFeeStructures = await this.prisma.feeStructure.findMany({
      where: { assignments: { none: {} } },
    });
    if (orphanFeeStructures.length > 0) {
      await this.prisma.feeStructure.deleteMany({
        where: { id: { in: orphanFeeStructures.map((f) => f.id) } },
      });
    }

    const [announcements, events, activities] = await Promise.all([
      this.prisma.announcement.deleteMany(),
      this.prisma.event.deleteMany(),
      this.prisma.activityLog.deleteMany(),
    ]);

    return {
      removed: {
        students: demoStudentIds.length,
        teachers: teacherUserIds.length,
        demoAdmins: demoAdminIds.length,
        classes: classesRemoved,
        announcements: announcements.count,
        events: events.count,
        activities: activities.count,
      },
      kept: {
        adminLogin: 'admin@school.demo',
      },
    };
  }
}
