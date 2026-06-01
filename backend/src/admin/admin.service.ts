import { Injectable } from '@nestjs/common';
import { Prisma, StudentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

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
}
