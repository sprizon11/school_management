import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AttendanceStatus, StudentStatus } from '@prisma/client';
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

  private static toMinutes(label: string) {
    const [time, meridiem] = label.split(' ');
    const [h, m] = time.split(':').map(Number);
    const hour = (h % 12) + (meridiem === 'PM' ? 12 : 0);
    return hour * 60 + (m || 0);
  }

  /**
   * Per-day timetable. `day` is a JS weekday index (0=Sun … 6=Sat);
   * defaults to today. Slots the teacher saved via saveSchedule() take
   * priority; otherwise periods are generated deterministically from the
   * teacher's assigned classes and subjects so every weekday is stable
   * but different. Sunday is a holiday (empty unless explicitly saved).
   */
  async schedule(teacherId: string, day?: number) {
    const now = new Date();
    const today = now.getDay();
    const weekday =
      day !== undefined && day >= 0 && day <= 6 ? Math.trunc(day) : today;

    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    const isToday = weekday === today;
    const withCurrent = (slot: {
      period: number;
      start: string;
      end: string;
      subject: string;
      classLabel: string;
      room: string;
    }) => ({
      ...slot,
      timeLabel: `${slot.start} - ${slot.end}`,
      location: slot.room,
      current:
        isToday &&
        nowMinutes >= TeacherService.toMinutes(slot.start) &&
        nowMinutes <= TeacherService.toMinutes(slot.end),
    });

    // Teacher-edited slots win over the generated defaults.
    const saved = await this.prisma.timetableSlot.findMany({
      where: { teacherId, dayOfWeek: weekday },
      orderBy: { period: 'asc' },
    });
    if (saved.length > 0) {
      return saved.map((s) =>
        withCurrent({
          period: s.period,
          start: s.start,
          end: s.end,
          subject: s.subject,
          classLabel: s.classLabel,
          room: s.room,
        }),
      );
    }

    if (weekday === 0) return [];

    const teacher = await this.prisma.teacher.findUnique({
      where: { id: teacherId },
      include: { classes: true },
    });
    const subjects = teacher?.subjects?.length
      ? teacher.subjects
      : ['Mathematics'];
    const classes = await this.prisma.class.findMany({
      where: { id: { in: await this.classIdsForTeacher(teacherId) } },
      orderBy: [{ grade: 'asc' }, { section: 'asc' }],
    });
    if (classes.length === 0) return [];

    const times = [
      { start: '08:00 AM', end: '08:45 AM' },
      { start: '09:00 AM', end: '09:45 AM' },
      { start: '10:00 AM', end: '10:45 AM' },
      { start: '11:00 AM', end: '11:45 AM' },
      { start: '12:00 PM', end: '12:45 PM' },
      { start: '02:00 PM', end: '02:45 PM' },
    ];

    return times.map((t, i) => {
      const cls = classes[(i + weekday) % classes.length];
      const gradeSection = `${cls.grade}${cls.section}`;
      const roomRaw = cls.room?.trim();
      const room = roomRaw
        ? /^(room|lab|hall)/i.test(roomRaw)
          ? roomRaw
          : `Room ${roomRaw}`
        : 'Room 101';
      return withCurrent({
        period: i + 1,
        start: t.start,
        end: t.end,
        subject: subjects[(i + weekday) % subjects.length],
        classLabel: `Class ${gradeSection}`,
        room,
      });
    });
  }

  /**
   * Replace the teacher's saved timetable for one weekday. An empty
   * `slots` array clears the override so the generated defaults return.
   */
  async saveSchedule(
    teacherId: string,
    day: number,
    slots: Array<{
      start?: string;
      end?: string;
      subject?: string;
      classLabel?: string;
      room?: string;
    }>,
  ) {
    if (!Number.isInteger(day) || day < 0 || day > 6) {
      throw new BadRequestException('day must be 0–6');
    }
    const clean = (slots ?? []).slice(0, 12).map((s, i) => ({
      teacherId,
      dayOfWeek: day,
      period: i + 1,
      start: `${s.start ?? ''}`.trim() || '08:00 AM',
      end: `${s.end ?? ''}`.trim() || '08:45 AM',
      subject: `${s.subject ?? ''}`.trim() || 'Class',
      classLabel: `${s.classLabel ?? ''}`.trim(),
      room: `${s.room ?? ''}`.trim(),
    }));

    await this.prisma.$transaction([
      this.prisma.timetableSlot.deleteMany({
        where: { teacherId, dayOfWeek: day },
      }),
      ...(clean.length > 0
        ? [this.prisma.timetableSlot.createMany({ data: clean })]
        : []),
    ]);

    return this.schedule(teacherId, day);
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

  /** Subject names this teacher can record marks for in a given class. */
  async subjectOptionsForClass(classId: string, teacherId: string) {
    await this.assertClassAccess(classId, teacherId);
    const [teaching, teacher] = await Promise.all([
      this.prisma.teacherTeachingClass.findMany({
        where: { teacherId, classId },
        select: { subject: true },
      }),
      this.prisma.teacher.findUnique({
        where: { id: teacherId },
        select: { subjects: true },
      }),
    ]);
    const names = new Set<string>();
    for (const t of teaching) {
      if (t.subject) names.add(t.subject);
    }
    for (const s of teacher?.subjects ?? []) {
      names.add(s);
    }
    if (names.size === 0) {
      ['English', 'Maths', 'Science', 'Social Science'].forEach((s) =>
        names.add(s),
      );
    }
    return [...names];
  }

  async createHomework(
    teacherId: string,
    dto: { classId: string; title: string; description?: string; dueDate: string },
  ) {
    await this.assertClassAccess(dto.classId, teacherId);
    const title = dto.title?.trim();
    if (!title) throw new BadRequestException('Title is required');
    const dueDate = new Date(dto.dueDate);
    if (Number.isNaN(dueDate.getTime())) {
      throw new BadRequestException('Invalid due date');
    }

    return this.prisma.homework.create({
      data: {
        classId: dto.classId,
        teacherId,
        title,
        description: dto.description?.trim() || null,
        dueDate,
      },
    });
  }

  private static gradeForPercent(pct: number): string {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 35) return 'D';
    return 'F';
  }

  async saveMarks(
    teacherId: string,
    dto: {
      classId: string;
      subjectName: string;
      termLabel: string;
      maxMarks?: number;
      entries: Array<{ studentId: string; marks: number; remarks?: string }>;
    },
  ) {
    await this.assertClassAccess(dto.classId, teacherId);

    const subjectName = dto.subjectName?.trim();
    const termLabel = dto.termLabel?.trim();
    if (!subjectName) throw new BadRequestException('Subject is required');
    if (!termLabel) throw new BadRequestException('Exam name is required');
    if (!Array.isArray(dto.entries) || dto.entries.length === 0) {
      throw new BadRequestException('At least one mark is required');
    }

    const maxMarks = dto.maxMarks && dto.maxMarks > 0 ? dto.maxMarks : 100;

    const subject = await this.prisma.subject.upsert({
      where: { name: subjectName },
      update: {},
      create: { name: subjectName },
    });

    const classStudentIds = new Set(
      (
        await this.prisma.student.findMany({
          where: { classId: dto.classId },
          select: { id: true },
        })
      ).map((s) => s.id),
    );

    let saved = 0;
    for (const entry of dto.entries) {
      if (!classStudentIds.has(entry.studentId)) continue;
      const marks = Math.max(0, Math.min(maxMarks, Math.round(entry.marks)));
      const grade = TeacherService.gradeForPercent((marks / maxMarks) * 100);

      const existing = await this.prisma.mark.findFirst({
        where: {
          studentId: entry.studentId,
          subjectId: subject.id,
          termLabel,
        },
      });

      if (existing) {
        await this.prisma.mark.update({
          where: { id: existing.id },
          data: { marks, maxMarks, grade, remarks: entry.remarks?.trim() || null, teacherId },
        });
      } else {
        await this.prisma.mark.create({
          data: {
            studentId: entry.studentId,
            subjectId: subject.id,
            teacherId,
            termLabel,
            maxMarks,
            marks,
            grade,
            remarks: entry.remarks?.trim() || null,
          },
        });
      }
      saved++;
    }

    return { saved, subject: subjectName, termLabel };
  }

  async reportsOverview(classId: string) {
    const students = await this.prisma.student.findMany({
      where: { classId },
      select: {
        id: true,
        fullName: true,
        rollNumber: true,
        gender: true,
        marks: { select: { marks: true, maxMarks: true } },
        attendance: { select: { status: true } },
      },
    });

    const withStats = students.map((s) => {
      const totalMax = s.marks.reduce((a, m) => a + m.maxMarks, 0);
      const totalGot = s.marks.reduce((a, m) => a + m.marks, 0);
      const avgMarks =
        totalMax > 0 ? Math.round((totalGot / totalMax) * 100) : null;

      const attTotal = s.attendance.length;
      const attPresent = s.attendance.filter(
        (a) => a.status === AttendanceStatus.PRESENT,
      ).length;
      const attendancePercent =
        attTotal > 0 ? Math.round((attPresent / attTotal) * 100) : null;

      return {
        id: s.id,
        fullName: s.fullName,
        rollNumber: s.rollNumber,
        gender: s.gender,
        avgMarks,
        attendancePercent,
      };
    });

    const marked = withStats.filter((s) => s.avgMarks !== null);
    const attended = withStats.filter((s) => s.attendancePercent !== null);

    const avg = (nums: number[]) =>
      nums.length > 0
        ? Math.round(nums.reduce((a, b) => a + b, 0) / nums.length)
        : 0;

    return {
      totalStudents: students.length,
      averageAttendance: avg(attended.map((s) => s.attendancePercent!)),
      classAverageMarks: avg(marked.map((s) => s.avgMarks!)),
      passPercentage:
        marked.length > 0
          ? Math.round(
              (marked.filter((s) => s.avgMarks! >= 35).length /
                marked.length) *
                100,
            )
          : 0,
      topStudents: [...marked]
        .sort((a, b) => b.avgMarks! - a.avgMarks!)
        .slice(0, 5),
      topAttendance: [...attended]
        .sort((a, b) => b.attendancePercent! - a.attendancePercent!)
        .slice(0, 5),
    };
  }

  async attendanceReport(classId: string) {
    const students = await this.prisma.student.findMany({
      where: { classId },
      orderBy: { rollNumber: 'asc' },
      select: {
        id: true,
        fullName: true,
        rollNumber: true,
        gender: true,
        attendance: { select: { status: true } },
      },
    });

    const rows = students.map((s) => {
      const total = s.attendance.length;
      const present = s.attendance.filter(
        (a) => a.status === AttendanceStatus.PRESENT,
      ).length;
      const absent = s.attendance.filter(
        (a) => a.status === AttendanceStatus.ABSENT,
      ).length;
      const leave = s.attendance.filter(
        (a) => a.status === AttendanceStatus.LEAVE,
      ).length;
      const percent = total > 0 ? Math.round((present / total) * 100) : null;

      return {
        id: s.id,
        fullName: s.fullName,
        rollNumber: s.rollNumber,
        gender: s.gender,
        present,
        absent,
        leave,
        total,
        percent,
      };
    });

    const withData = rows.filter((r) => r.total > 0);
    const classAverage =
      withData.length > 0
        ? Math.round(
            withData.reduce((a, r) => a + (r.percent ?? 0), 0) /
              withData.length,
          )
        : 0;
    const totalSessions = rows.reduce((a, r) => a + r.total, 0);
    const totalLeaves = rows.reduce((a, r) => a + r.leave, 0);
    const totalAbsences = rows.reduce((a, r) => a + r.absent, 0);

    return {
      classAverage,
      totalSessions,
      totalLeaves,
      totalAbsences,
      students: rows,
    };
  }

  async marksReport(classId: string) {
    const students = await this.prisma.student.findMany({
      where: { classId },
      orderBy: { rollNumber: 'asc' },
      select: {
        id: true,
        fullName: true,
        rollNumber: true,
        gender: true,
        marks: {
          select: {
            marks: true,
            maxMarks: true,
            grade: true,
            subject: { select: { name: true } },
          },
        },
      },
    });

    const rows = students.map((s) => {
      const totalMax = s.marks.reduce((a, m) => a + m.maxMarks, 0);
      const totalGot = s.marks.reduce((a, m) => a + m.marks, 0);
      const percent =
        totalMax > 0 ? Math.round((totalGot / totalMax) * 100) : null;
      return {
        id: s.id,
        fullName: s.fullName,
        rollNumber: s.rollNumber,
        gender: s.gender,
        percent,
        totalGot,
        totalMax,
        subjects: s.marks.map((m) => ({
          name: m.subject.name,
          marks: m.marks,
          maxMarks: m.maxMarks,
          grade: m.grade,
        })),
      };
    });

    const graded = rows.filter((r) => r.percent !== null);
    const classAverage =
      graded.length > 0
        ? Math.round(
            graded.reduce((a, r) => a + (r.percent ?? 0), 0) / graded.length,
          )
        : 0;
    const passRate =
      graded.length > 0
        ? Math.round(
            (graded.filter((r) => (r.percent ?? 0) >= 35).length /
              graded.length) *
              100,
          )
        : 0;

    return {
      classAverage,
      passRate,
      gradedCount: graded.length,
      students: rows,
    };
  }

  async performanceReport(classId: string) {
    const students = await this.prisma.student.findMany({
      where: { classId },
      orderBy: { rollNumber: 'asc' },
      select: {
        id: true,
        fullName: true,
        rollNumber: true,
        gender: true,
        marks: { select: { marks: true, maxMarks: true } },
        attendance: { select: { status: true } },
      },
    });

    const rows = students.map((s) => {
      const tm = s.marks.reduce((a, m) => a + m.maxMarks, 0);
      const tg = s.marks.reduce((a, m) => a + m.marks, 0);
      const marksPercent = tm > 0 ? Math.round((tg / tm) * 100) : null;
      const at = s.attendance.length;
      const ap = s.attendance.filter(
        (a) => a.status === AttendanceStatus.PRESENT,
      ).length;
      const attendancePercent = at > 0 ? Math.round((ap / at) * 100) : null;
      let score: number | null = null;
      if (marksPercent !== null && attendancePercent !== null) {
        score = Math.round(marksPercent * 0.7 + attendancePercent * 0.3);
      } else {
        score = marksPercent ?? attendancePercent;
      }
      return {
        id: s.id,
        fullName: s.fullName,
        rollNumber: s.rollNumber,
        gender: s.gender,
        marksPercent,
        attendancePercent,
        score,
        rank: null as number | null,
      };
    });

    const ranked = rows
      .filter((r) => r.score !== null)
      .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
    ranked.forEach((r, i) => {
      r.rank = i + 1;
    });

    return { students: rows };
  }

  async assignmentsReport(classId: string) {
    const items = await this.prisma.homework.findMany({
      where: { classId },
      orderBy: { dueDate: 'desc' },
    });
    const now = new Date();
    return {
      total: items.length,
      upcoming: items.filter((h) => h.dueDate >= now).length,
      past: items.filter((h) => h.dueDate < now).length,
      items: items.map((h) => ({
        id: h.id,
        title: h.title,
        description: h.description,
        dueDate: h.dueDate,
        createdAt: h.createdAt,
        status: h.dueDate >= now ? 'upcoming' : 'past',
      })),
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
