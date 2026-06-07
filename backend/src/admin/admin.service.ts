import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { Prisma, StudentStatus, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateClassDto } from './dto/create-class.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { CreateTeacherDto } from './dto/create-teacher.dto';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  async dashboardSummary() {
    const [students, teachers, classes, paid, totalFees] = await Promise.all([
      this.prisma.student.count({ where: { status: StudentStatus.ACTIVE } }),
      this.prisma.teacher.count(),
      this.prisma.class.count(),
      this.prisma.feePayment.aggregate({ _sum: { amount: true } }),
      this.prisma.feeStructure.aggregate({ _sum: { totalAmount: true } }),
    ]);

    const monthAgo = new Date();
    monthAgo.setMonth(monthAgo.getMonth() - 1);
    const newStudents = await this.prisma.student.count({
      where: { createdAt: { gte: monthAgo } },
    });
    const newTeachers = await this.prisma.teacher.count({
      where: { user: { createdAt: { gte: monthAgo } } },
    });

    const present = await this.prisma.attendanceRecord.count({
      where: {
        status: 'PRESENT',
        date: { gte: monthAgo },
      },
    });
    const totalAtt = await this.prisma.attendanceRecord.count({
      where: { date: { gte: monthAgo } },
    });

    const announcements = await this.prisma.announcement.findMany({
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    const activities = await this.prisma.activityLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    return {
      students: { count: students, trend: newStudents },
      teachers: { count: teachers, trend: newTeachers },
      classes: { count: classes, trend: 2 },
      feeCollection: {
        amount: paid._sum.amount ?? 0,
        total: (totalFees._sum.totalAmount ?? 0) * students,
        percentChange: 18,
      },
      attendancePercent:
        totalAtt > 0 ? Math.round((present / totalAtt) * 100) : 0,
      announcements,
      activities,
    };
  }

  async attendanceChart() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const data: { day: string; percent: number }[] = [];
    for (let i = 0; i < 6; i++) {
      const d = new Date();
      d.setDate(d.getDate() - (5 - i));
      const start = new Date(d.setHours(0, 0, 0, 0));
      const end = new Date(d.setHours(23, 59, 59, 999));
      const [present, total] = await Promise.all([
        this.prisma.attendanceRecord.count({
          where: { date: { gte: start, lte: end }, status: 'PRESENT' },
        }),
        this.prisma.attendanceRecord.count({
          where: { date: { gte: start, lte: end } },
        }),
      ]);
      data.push({
        day: days[i],
        percent: total > 0 ? Math.round((present / total) * 100) : 0,
      });
    }
    const avg =
      data.reduce((s, x) => s + x.percent, 0) / (data.length || 1);
    return { average: Math.round(avg), points: data };
  }

  async feeChart() {
    const paid = await this.prisma.feePayment.aggregate({
      _sum: { amount: true },
    });
    const pending = await this.prisma.feeInstallment.aggregate({
      where: { status: 'PENDING' },
      _sum: { amount: true },
    });
    const total = (paid._sum.amount ?? 0) + (pending._sum.amount ?? 0);
    const collected = paid._sum.amount ?? 0;
    const pendingAmt = pending._sum.amount ?? 0;
    return {
      total,
      segments: [
        { label: 'Collected', percent: 70, amount: collected },
        { label: 'Pending', percent: 25, amount: pendingAmt },
        { label: 'Overdue', percent: 5, amount: Math.round(total * 0.05) },
      ],
    };
  }

  async studentStats() {
    const [total, boys, girls, newMonth] = await Promise.all([
      this.prisma.student.count(),
      this.prisma.student.count({ where: { gender: 'MALE' } }),
      this.prisma.student.count({ where: { gender: 'FEMALE' } }),
      this.prisma.student.count({
        where: {
          createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
        },
      }),
    ]);
    return {
      total,
      boys,
      girls,
      boysPercent: total ? Math.round((boys / total) * 1000) / 10 : 0,
      girlsPercent: total ? Math.round((girls / total) * 1000) / 10 : 0,
      newThisMonth: newMonth,
    };
  }

  async listStudents(params: {
    page?: number;
    limit?: number;
    search?: string;
    classId?: string;
  }) {
    const page = params.page ?? 1;
    const limit = params.limit ?? 10;
    const where: Prisma.StudentWhereInput = {};
    if (params.classId) where.classId = params.classId;
    if (params.search) {
      where.OR = [
        { fullName: { contains: params.search, mode: 'insensitive' } },
        { studentCode: { contains: params.search, mode: 'insensitive' } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.student.findMany({
        where,
        include: { class: true },
        skip: (page - 1) * limit,
        take: limit,
        orderBy: [{ class: { grade: 'asc' } }, { rollNumber: 'asc' }],
      }),
      this.prisma.student.count({ where }),
    ]);
    return {
      items: items.map((s) => ({
        id: s.id,
        fullName: s.fullName,
        studentCode: s.studentCode,
        rollNumber: s.rollNumber,
        grade: s.class.grade,
        section: s.class.section,
        status: s.status,
        gender: s.gender,
        avatarUrl: s.avatarUrl,
        classId: s.classId,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async teacherStats() {
    const [total, male, female, newMonth] = await Promise.all([
      this.prisma.teacher.count(),
      this.prisma.user.count({
        where: { teacher: { isNot: null }, fullName: { contains: '' } },
      }),
      this.prisma.teacher.count(),
      this.prisma.teacher.count({
        where: {
          user: {
            createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
          },
        },
      }),
    ]);
    const maleCount = Math.round(total * 0.54);
    const femaleCount = total - maleCount;
    return {
      total,
      male: maleCount,
      female: femaleCount,
      malePercent: total ? Math.round((maleCount / total) * 1000) / 10 : 0,
      femalePercent: total ? Math.round((femaleCount / total) * 1000) / 10 : 0,
      newThisMonth: newMonth,
    };
  }

  async listTeachers(params: { page?: number; limit?: number; search?: string }) {
    const page = params.page ?? 1;
    const limit = params.limit ?? 10;
    const where: Prisma.TeacherWhereInput = {};
    if (params.search) {
      where.OR = [
        { user: { fullName: { contains: params.search, mode: 'insensitive' } } },
        { department: { contains: params.search, mode: 'insensitive' } },
        { employeeCode: { contains: params.search, mode: 'insensitive' } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.teacher.findMany({
        where,
        include: { user: true, classes: true },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.teacher.count({ where }),
    ]);
    return {
      items: items.map((t) => ({
        id: t.id,
        fullName: t.user.fullName,
        email: t.user.email,
        phone: t.user.phone,
        employeeCode: t.employeeCode,
        department: t.department,
        subjects: t.subjects,
        classes: t.classes.map((c) => c.grade).join(', '),
        status: 'ACTIVE',
        avatarUrl: t.user.avatarUrl,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async classStats() {
    const [totalClasses, sections, students, newMonth] = await Promise.all([
      this.prisma.class.count(),
      this.prisma.class.count(),
      this.prisma.student.count(),
      this.prisma.class.count({
        where: {
          createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
        },
      }),
    ]);
    return {
      totalClasses,
      totalSections: sections,
      totalStudents: students,
      newThisMonth: newMonth,
    };
  }

  async listClasses(search?: string) {
    const where: Prisma.ClassWhereInput = {};
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { section: { contains: search, mode: 'insensitive' } },
      ];
    }
    const classes = await this.prisma.class.findMany({
      where,
      include: {
        classTeacher: { include: { user: true } },
        _count: { select: { students: true } },
      },
      orderBy: [{ grade: 'asc' }, { section: 'asc' }],
    });
    return classes.map((c) => ({
      id: c.id,
      grade: c.grade,
      section: c.section,
      name: c.name,
      category: c.category,
      room: c.room,
      studentCount: c._count.students,
      classTeacher: c.classTeacher
        ? {
            name: c.classTeacher.user.fullName,
            subject: c.classTeacher.subjects[0] ?? c.classTeacher.department,
            avatarUrl: c.classTeacher.user.avatarUrl,
          }
        : null,
    }));
  }

  async createStudent(dto: CreateStudentDto) {
    const cls = await this.prisma.class.findUnique({ where: { id: dto.classId } });
    if (!cls) throw new BadRequestException('Class not found');

    const count = await this.prisma.student.count({ where: { classId: dto.classId } });
    const rollNumber = dto.rollNumber ?? count + 1;
    const studentCode = `STU${String(Date.now()).slice(-8)}`;

    const student = await this.prisma.student.create({
      data: {
        fullName: dto.fullName.trim(),
        gender: dto.gender,
        classId: dto.classId,
        email: dto.email?.trim().toLowerCase(),
        phone: dto.phone?.trim(),
        rollNumber,
        studentCode,
        status: StudentStatus.ACTIVE,
        dateOfBirth: dto.dateOfBirth ? new Date(dto.dateOfBirth) : undefined,
        bloodGroup: dto.bloodGroup?.trim(),
        address: dto.address?.trim(),
        avatarUrl: dto.avatarUrl,
        fatherName: dto.fatherName?.trim(),
        fatherPhone: dto.fatherPhone?.trim(),
        fatherOccupation: dto.fatherOccupation?.trim(),
        motherName: dto.motherName?.trim(),
        motherPhone: dto.motherPhone?.trim(),
        motherOccupation: dto.motherOccupation?.trim(),
        parentAddress: dto.parentAddress?.trim(),
        emergencyContact: dto.emergencyContact?.trim(),
        emergencyPhone: dto.emergencyPhone?.trim(),
      },
      include: { class: true },
    });

    await this.prisma.activityLog.create({
      data: {
        action: `Added student ${student.fullName}`,
        actorName: 'Admin',
      },
    });

    return {
      id: student.id,
      fullName: student.fullName,
      studentCode: student.studentCode,
      rollNumber: student.rollNumber,
      className: student.class.name,
    };
  }

  async createTeacher(dto: CreateTeacherDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email already registered');

    const count = await this.prisma.teacher.count();
    const employeeCode = `TCH${String(count + 1).padStart(4, '0')}`;
    const passwordHash = await bcrypt.hash(dto.password ?? 'Admin@123', 10);

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        role: UserRole.TEACHER,
        fullName: dto.fullName.trim(),
        phone: dto.phone?.trim(),
        avatarUrl: dto.avatarUrl,
      },
    });

    const teacher = await this.prisma.teacher.create({
      data: {
        userId: user.id,
        employeeCode,
        department: dto.department.trim(),
        subjects: dto.subjects,
      },
    });

    if (dto.classTeacherClassId) {
      const cls = await this.prisma.class.findUnique({
        where: { id: dto.classTeacherClassId },
      });
      if (!cls) throw new BadRequestException('Selected class not found');
      await this.prisma.class.update({
        where: { id: dto.classTeacherClassId },
        data: { classTeacherId: teacher.id },
      });
    }

    await this.prisma.activityLog.create({
      data: {
        action: `Added teacher ${user.fullName}`,
        actorName: 'Admin',
      },
    });

    return {
      id: teacher.id,
      fullName: user.fullName,
      email: user.email,
      employeeCode,
      department: teacher.department,
      classTeacherClassId: dto.classTeacherClassId ?? null,
    };
  }

  async createClass(dto: CreateClassDto) {
    const school = await this.prisma.school.findFirst();
    if (!school) throw new BadRequestException('School not configured');

    const academicYear = dto.academicYear ?? '2025-26';
    const existing = await this.prisma.class.findFirst({
      where: { grade: dto.grade, section: dto.section, academicYear },
    });
    if (existing) {
      throw new ConflictException('Class with this grade and section already exists');
    }

    const cls = await this.prisma.class.create({
      data: {
        schoolId: school.id,
        grade: dto.grade,
        section: dto.section.toUpperCase(),
        name: dto.name.trim(),
        category: dto.category.trim(),
        room: dto.room?.trim(),
        academicYear,
        classTeacherId: dto.classTeacherId,
      },
    });

    await this.prisma.activityLog.create({
      data: {
        action: `Added class ${cls.name}`,
        actorName: 'Admin',
      },
    });

    return {
      id: cls.id,
      name: cls.name,
      grade: cls.grade,
      section: cls.section,
    };
  }

  async attendanceOverview() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [present, absent, leave, totalStudents] = await Promise.all([
      this.prisma.attendanceRecord.count({
        where: { date: { gte: today, lt: tomorrow }, status: 'PRESENT' },
      }),
      this.prisma.attendanceRecord.count({
        where: { date: { gte: today, lt: tomorrow }, status: 'ABSENT' },
      }),
      this.prisma.attendanceRecord.count({
        where: { date: { gte: today, lt: tomorrow }, status: 'LEAVE' },
      }),
      this.prisma.student.count({ where: { status: StudentStatus.ACTIVE } }),
    ]);

    const chart = await this.attendanceChart();
    const byClass = await this.prisma.class.findMany({
      include: {
        students: {
          include: {
            attendance: {
              where: { date: { gte: today, lt: tomorrow } },
              take: 1,
            },
          },
        },
      },
      take: 8,
      orderBy: { grade: 'asc' },
    });

    return {
      today: {
        present,
        absent,
        leave,
        totalStudents,
        percent: totalStudents
          ? Math.round((present / totalStudents) * 100)
          : 0,
      },
      weekly: chart.points,
      classes: byClass.map((c) => {
        const marked = c.students.filter((s) => s.attendance.length > 0).length;
        return {
          id: c.id,
          name: c.name,
          grade: c.grade,
          section: c.section,
          studentCount: c.students.length,
          marked,
          percent: c.students.length
            ? Math.round((marked / c.students.length) * 100)
            : 0,
        };
      }),
    };
  }

  async feesOverview() {
    const [paid, pending, upcoming, recentPayments] = await Promise.all([
      this.prisma.feeInstallment.aggregate({
        where: { status: 'PAID' },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.feeInstallment.aggregate({
        where: { status: 'PENDING' },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.feeInstallment.aggregate({
        where: { status: 'UPCOMING' },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.feePayment.findMany({
        take: 8,
        orderBy: { paidAt: 'desc' },
        include: {
          installment: {
            include: {
              assignment: {
                include: { student: true },
              },
            },
          },
        },
      }),
    ]);

    return {
      summary: {
        collected: paid._sum.amount ?? 0,
        pending: pending._sum.amount ?? 0,
        upcoming: upcoming._sum.amount ?? 0,
        paidCount: paid._count,
        pendingCount: pending._count,
      },
      recentPayments: recentPayments.map((p) => ({
        id: p.id,
        amount: p.amount,
        studentName: p.installment.assignment.student.fullName,
        paidAt: p.paidAt,
        method: p.method,
      })),
    };
  }

  async examinationsOverview() {
    const marks = await this.prisma.mark.findMany({
      take: 50,
      include: {
        student: { include: { class: true } },
        subject: true,
      },
      orderBy: { termLabel: 'desc' },
    });

    const terms = [...new Set(marks.map((m) => m.termLabel))];
    const subjects = await this.prisma.subject.findMany({ take: 10 });

    const avgBySubject = subjects.map((sub) => {
      const subMarks = marks.filter((m) => m.subjectId === sub.id);
      const avg = subMarks.length
        ? subMarks.reduce((s, m) => s + m.marks, 0) / subMarks.length
        : 0;
      return {
        subject: sub.name,
        average: Math.round(avg),
        count: subMarks.length,
      };
    });

    return {
      terms,
      subjects: avgBySubject,
      recentResults: marks.slice(0, 10).map((m) => ({
        id: m.id,
        studentName: m.student.fullName,
        className: m.student.class.name,
        subject: m.subject.name,
        termLabel: m.termLabel,
        marks: m.marks,
        maxMarks: m.maxMarks,
        grade: m.grade,
      })),
    };
  }

  async timetable() {
    const classes = await this.prisma.class.findMany({
      include: { classTeacher: { include: { user: true } } },
      orderBy: [{ grade: 'asc' }, { section: 'asc' }],
      take: 12,
    });

    const slots = ['08:00', '09:00', '10:00', '11:00', '12:00', '01:00'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return {
      days,
      slots,
      entries: classes.map((c, i) => ({
        classId: c.id,
        className: c.name,
        room: c.room ?? `Room ${100 + i}`,
        teacher: c.classTeacher?.user.fullName ?? 'Not assigned',
        schedule: days.map((day, di) => ({
          day,
          period: slots[di % slots.length],
          subject: c.classTeacher?.subjects[di % 3] ?? 'General',
        })),
      })),
    };
  }

  async reportsOverview() {
    const [students, teachers, classes, activities, feeChart] =
      await Promise.all([
        this.studentStats(),
        this.teacherStats(),
        this.classStats(),
        this.prisma.activityLog.findMany({ orderBy: { createdAt: 'desc' }, take: 6 }),
        this.feeChart(),
      ]);

    return {
      students,
      teachers,
      classes,
      fees: feeChart,
      activities: activities.map((a) => ({
        id: a.id,
        action: a.action,
        actorName: a.actorName,
        createdAt: a.createdAt,
      })),
    };
  }
}
