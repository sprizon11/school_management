import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { StudentStatus } from '@prisma/client';
import { ensureParentAccount } from '../common/parent-account';
import { CreateStudentDto } from '../admin/dto/create-student.dto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TeacherService {
  constructor(private prisma: PrismaService) {}

  private async classIdsForTeacher(teacherId: string) {
    const [asClassTeacher, teaching] = await Promise.all([
      this.prisma.class.findMany({
        where: { classTeacherId: teacherId },
        select: { id: true },
      }),
      this.prisma.teacherTeachingClass.findMany({
        where: { teacherId },
        select: { classId: true },
      }),
    ]);
    return [
      ...new Set([
        ...asClassTeacher.map((c) => c.id),
        ...teaching.map((t) => t.classId),
      ]),
    ];
  }

  private async assertClassAccess(classId: string, teacherId: string) {
    const ids = await this.classIdsForTeacher(teacherId);
    if (!ids.includes(classId)) {
      throw new ForbiddenException('You are not assigned to this class');
    }
  }

  private async assertClassTeacher(classId: string, teacherId: string) {
    const cls = await this.prisma.class.findFirst({
      where: { id: classId, classTeacherId: teacherId },
    });
    if (!cls) {
      throw new ForbiddenException(
        'Only the class teacher can add students to this class',
      );
    }
    return cls;
  }

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

    const classIds = await this.classIdsForTeacher(teacherId);
    const [pendingHomework, totalStudents] = await Promise.all([
      this.prisma.homework.count({
        where: { teacherId, dueDate: { gte: new Date() } },
      }),
      classIds.length > 0
        ? this.prisma.student.count({ where: { classId: { in: classIds } } })
        : Promise.resolve(0),
    ]);

    return {
      teacher: {
        fullName: teacher.user.fullName,
        employeeCode: teacher.employeeCode,
        department: teacher.department,
        subjects: teacher.subjects,
        classes: teacher.classes.map((c) => `${c.grade}${c.section}`),
      },
      classCount: classIds.length,
      totalStudents,
      classesToday: classIds.length > 0 ? Math.min(4, classIds.length) : 0,
      pendingGrading: pendingHomework,
      tasksCount: pendingHomework + 3,
      attendanceMarkedPercent: 85,
      leaveRequestsPending: 3,
    };
  }

  async upcomingHomework(teacherId: string) {
    return this.prisma.homework.findMany({
      where: { teacherId, dueDate: { gte: new Date() } },
      include: { class: true },
      orderBy: { dueDate: 'asc' },
      take: 6,
    });
  }

  async schedule(teacherId: string) {
    const teacher = await this.prisma.teacher.findUnique({
      where: { id: teacherId },
      include: { classes: true },
    });
    const subjects = teacher?.subjects ?? ['Mathematics'];
    const classes = await this.prisma.class.findMany({
      where: { id: { in: await this.classIdsForTeacher(teacherId) } },
    });
    const times = [
      { start: '08:00 AM', end: '08:45 AM' },
      { start: '09:00 AM', end: '09:45 AM' },
      { start: '10:00 AM', end: '10:45 AM' },
      { start: '11:00 AM', end: '11:45 AM' },
    ];
    return times.map((t, i) => {
      const cls = classes[i % Math.max(classes.length, 1)];
      const gradeSection = cls ? `${cls.grade}${cls.section}` : '9A';
      return {
        start: t.start,
        end: t.end,
        timeLabel: `${t.start} - ${t.end}`,
        subject: subjects[i % subjects.length] ?? 'Science',
        classLabel: `Class $gradeSection`,
        room: cls?.room ? `${cls.room}` : 'Room 203',
        location: cls?.room?.toLowerCase().includes('lab')
          ? cls.room
          : cls?.room
            ? `Room ${cls.room}`
            : 'Science Lab',
        current: i === 0,
      };
    });
  }

  async assignedClasses(teacherId: string) {
    const ids = await this.classIdsForTeacher(teacherId);
    if (ids.length === 0) return [];
    return this.prisma.class.findMany({
      where: { id: { in: ids } },
      include: {
        classTeacher: { include: { user: true } },
        _count: { select: { students: true } },
      },
      orderBy: [{ grade: 'asc' }, { section: 'asc' }],
    });
  }

  async classDetail(classId: string, teacherId: string) {
    await this.assertClassAccess(classId, teacherId);
    const cls = await this.prisma.class.findUnique({
      where: { id: classId },
      include: {
        classTeacher: { include: { user: true } },
        _count: { select: { students: true } },
      },
    });
    if (!cls) throw new NotFoundException('Class not found');
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

  async classStudents(
    classId: string,
    teacherId: string,
    page = 1,
    limit = 10,
    search?: string,
  ) {
    await this.assertClassAccess(classId, teacherId);
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

  async listAnnouncements(schoolId: string) {
    return this.prisma.announcement.findMany({
      where: { schoolId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async listNotifications(userId: string) {
    return this.prisma.appNotification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async unreadNotificationCount(userId: string) {
    return this.prisma.appNotification.count({
      where: { userId, readAt: null },
    });
  }

  async markNotificationRead(userId: string, id: string) {
    const note = await this.prisma.appNotification.findFirst({
      where: { id, userId },
    });
    if (!note) throw new NotFoundException('Notification not found');

    return this.prisma.appNotification.update({
      where: { id },
      data: { readAt: new Date() },
    });
  }

  async markAllNotificationsRead(userId: string) {
    await this.prisma.appNotification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }

  async createStudent(teacherId: string, schoolId: string, dto: CreateStudentDto) {
    await this.assertClassTeacher(dto.classId, teacherId);
    const cls = await this.prisma.class.findUnique({ where: { id: dto.classId } });
    if (!cls || cls.schoolId !== schoolId) {
      throw new BadRequestException('Class not found');
    }

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

    await ensureParentAccount(this.prisma, schoolId, student);

    return {
      id: student.id,
      fullName: student.fullName,
      studentCode: student.studentCode,
      rollNumber: student.rollNumber,
      className: student.class.name,
    };
  }
}
