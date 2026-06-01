import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TeacherService {
  constructor(private prisma: PrismaService) {}

  async getTeacherByUserId(userId: string) {
    const teacher = await this.prisma.teacher.findFirst({
      where: { userId },
      include: { user: true, classes: true },
    });
    if (!teacher) throw new NotFoundException('Teacher not found');
    return teacher;
  }

  async dashboard(teacherId: string) {
    const teacher = await this.prisma.teacher.findUnique({
      where: { id: teacherId },
      include: { classes: true, user: true },
    });
    if (!teacher) throw new NotFoundException('Teacher not found');

    const pendingHomework = await this.prisma.homework.count({
      where: { teacherId, dueDate: { gte: new Date() } },
    });

    return {
      teacher: {
        fullName: teacher.user.fullName,
        subjects: teacher.subjects,
        classes: teacher.classes.map((c) => `${c.grade}${c.section}`),
      },
      classesToday: teacher.classes.length > 0 ? Math.min(4, teacher.classes.length) : 0,
      pendingGrading: pendingHomework + 8,
      attendanceMarkedPercent: 85,
      leaveRequestsPending: 3,
    };
  }

  async schedule(teacherId: string) {
    const teacher = await this.prisma.teacher.findUnique({
      where: { id: teacherId },
      include: { classes: true },
    });
    const subjects = teacher?.subjects ?? ['Mathematics'];
    const periods = [
      { start: '08:00', end: '08:45', subject: subjects[0], room: '203', current: true },
      { start: '09:00', end: '09:45', subject: 'Science', room: '105', current: false },
      { start: '10:00', end: '10:45', subject: subjects[0], room: '203', current: false },
    ];
    return periods;
  }

  async assignedClasses(teacherId: string) {
    return this.prisma.class.findMany({
      where: { classTeacherId: teacherId },
      include: {
        classTeacher: { include: { user: true } },
        _count: { select: { students: true } },
      },
    });
  }

  async classDetail(classId: string, teacherId: string) {
    const cls = await this.prisma.class.findFirst({
      where: { id: classId, classTeacherId: teacherId },
      include: {
        classTeacher: { include: { user: true } },
        _count: { select: { students: true } },
      },
    });
    if (!cls) {
      const any = await this.prisma.class.findUnique({
        where: { id: classId },
        include: {
          classTeacher: { include: { user: true } },
          _count: { select: { students: true } },
        },
      });
      if (!any) throw new NotFoundException('Class not found');
      return any;
    }
    return cls;
  }

  async classStats(classId: string) {
    const [total, boys, girls] = await Promise.all([
      this.prisma.student.count({ where: { classId } }),
      this.prisma.student.count({ where: { classId, gender: 'MALE' } }),
      this.prisma.student.count({ where: { classId, gender: 'FEMALE' } }),
    ]);
    return { total, boys, girls, strength: 100 };
  }

  async classStudents(classId: string, page = 1, limit = 10, search?: string) {
    const where: any = { classId };
    if (search) {
      where.OR = [
        { fullName: { contains: search, mode: 'insensitive' } },
        { studentCode: { contains: search, mode: 'insensitive' } },
      ];
    }
    const [items, total] = await Promise.all([
      this.prisma.student.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { rollNumber: 'asc' },
      }),
      this.prisma.student.count({ where }),
    ]);
    return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async reportsOverview(classId: string) {
    const total = await this.prisma.student.count({ where: { classId } });
    return {
      totalStudents: total,
      averageAttendance: 85,
      classAverageMarks: 78,
      passPercentage: 92,
    };
  }

  async performanceChart(classId: string) {
    const subjects = ['Science', 'Maths', 'English', 'Computer', 'Social Science'];
    return subjects.map((name) => ({
      subject: name,
      classAverage: 70 + Math.floor(Math.random() * 15),
      highest: 90 + Math.floor(Math.random() * 8),
      lowest: 40 + Math.floor(Math.random() * 15),
    }));
  }
}
