import { Injectable, NotFoundException } from '@nestjs/common';
import { AttendanceStatus, type Announcement } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ParentService {
  constructor(private prisma: PrismaService) {}

  /**
   * Resolve the signed-in parent's child.
   *
   * `Parent` is linked 1:1 to a student, so everything a parent can read is
   * scoped through this lookup — there is no path for a parent to name a
   * student id and read someone else's record.
   */
  private async childFor(userId: string) {
    const parent = await this.prisma.parent.findFirst({
      where: { userId },
      include: {
        student: {
          include: {
            class: {
              include: { classTeacher: { include: { user: true } } },
            },
          },
        },
      },
    });
    if (!parent) {
      throw new NotFoundException('No student is linked to this account');
    }
    return parent.student;
  }

  /** UTC midnight `offsetDays` from today — matches how attendance is stored. */
  private static utcDay(offsetDays = 0): Date {
    const now = new Date();
    return new Date(
      Date.UTC(now.getFullYear(), now.getMonth(), now.getDate() + offsetDays),
    );
  }

  /** Everything the parent home screen shows, in one round trip. */
  async home(userId: string) {
    const student = await this.childFor(userId);
    const schoolId = student.class?.schoolId;

    const monthStart = (() => {
      const now = new Date();
      return new Date(Date.UTC(now.getFullYear(), now.getMonth(), 1));
    })();
    const weekAhead = ParentService.utcDay(7);

    const [
      present,
      absent,
      leave,
      marks,
      homework,
      absentThisMonth,
      dueThisWeek,
      announcement,
      school,
      datedNotices,
    ] = await Promise.all([
      this.prisma.attendanceRecord.count({
        where: { studentId: student.id, status: AttendanceStatus.PRESENT },
      }),
      this.prisma.attendanceRecord.count({
        where: { studentId: student.id, status: AttendanceStatus.ABSENT },
      }),
      this.prisma.attendanceRecord.count({
        where: { studentId: student.id, status: AttendanceStatus.LEAVE },
      }),
      this.prisma.mark.findMany({
        where: { studentId: student.id },
        include: { subject: true },
        orderBy: { termLabel: 'desc' },
      }),
      this.prisma.homework.findMany({
        where: { classId: student.classId, dueDate: { gte: new Date() } },
        orderBy: { dueDate: 'asc' },
        take: 5,
      }),
      this.prisma.attendanceRecord.count({
        where: {
          studentId: student.id,
          status: AttendanceStatus.ABSENT,
          date: { gte: monthStart },
        },
      }),
      this.prisma.homework.count({
        where: {
          classId: student.classId,
          dueDate: { gte: new Date(), lt: weekAhead },
        },
      }),
      // Only announcements the school explicitly addressed to parents.
      schoolId
        ? this.prisma.announcement.findFirst({
            where: { schoolId, audience: 'TEACHERS_AND_PARENTS' },
            orderBy: { createdAt: 'desc' },
          })
        : Promise.resolve(null),
      schoolId
        ? this.prisma.school.findUnique({
            where: { id: schoolId },
            select: { name: true },
          })
        : Promise.resolve(null),
      // Candidate "upcoming test" notices: future-dated parent announcements.
      // The app has no exam entity, so a test is a dated announcement the
      // school posts; we keep only the ones whose title reads like one.
      schoolId
        ? this.prisma.announcement.findMany({
            where: {
              schoolId,
              audience: 'TEACHERS_AND_PARENTS',
              eventDate: { gte: ParentService.utcDay() },
            },
            orderBy: { eventDate: 'asc' },
            take: 12,
          })
        : Promise.resolve([] as Announcement[]),
    ]);

    const marked = present + absent + leave;
    // Leave is not counted against the child — it was authorised.
    const attended = present + leave;

    const scored = marks.map((m) => ({
      id: m.id,
      subject: m.subject.name,
      termLabel: m.termLabel,
      marks: m.marks,
      maxMarks: m.maxMarks,
      grade: m.grade,
      remarks: m.remarks,
      percent: m.maxMarks > 0 ? Math.round((m.marks / m.maxMarks) * 100) : 0,
    }));

    const average = scored.length
      ? Math.round(
          scored.reduce((sum, m) => sum + m.percent, 0) / scored.length,
        )
      : null;

    const testWords = /\b(test|exam|examination|quiz|assessment|unit test)\b/i;
    const upcomingTests = datedNotices
      .filter((a) => testWords.test(a.title))
      .slice(0, 5)
      .map((a) => ({
        id: a.id,
        title: a.title,
        body: a.body,
        eventDate: a.eventDate,
      }));

    return {
      child: {
        id: student.id,
        fullName: student.fullName,
        studentCode: student.studentCode,
        rollNumber: student.rollNumber,
        avatarUrl: student.avatarUrl,
        className: student.class?.name ?? '',
        classTeacher: student.class?.classTeacher?.user.fullName ?? null,
        schoolName: school?.name ?? '',
      },
      attendance: {
        present,
        absent,
        leave,
        marked,
        absentThisMonth,
        // Null rather than 0 — "no attendance taken yet" and "attended
        // nothing" are different things and the UI shows them differently.
        percent: marked > 0 ? Math.round((attended / marked) * 100) : null,
      },
      marks: {
        average,
        count: scored.length,
        recent: scored.slice(0, 5),
      },
      homework: homework.map((h) => ({
        id: h.id,
        title: h.title,
        description: h.description,
        dueDate: h.dueDate,
      })),
      upcomingTests,
      dueThisWeek,
      announcement: announcement
        ? {
            id: announcement.id,
            title: announcement.title,
            body: announcement.body,
            eventDate: announcement.eventDate,
            createdAt: announcement.createdAt,
          }
        : null,
    };
  }

  /** Fee summary and installment schedule for the child. */
  async fees(userId: string) {
    const student = await this.childFor(userId);

    const installments = await this.prisma.feeInstallment.findMany({
      where: { assignment: { studentId: student.id } },
      orderBy: { dueDate: 'asc' },
      include: {
        assignment: { include: { feeStructure: true } },
        payments: { orderBy: { paidAt: 'desc' }, take: 1 },
      },
    });

    const sum = (status: 'PAID' | 'PENDING' | 'UPCOMING') =>
      installments
        .filter((i) => i.status === status)
        .reduce((t, i) => t + i.amount, 0);

    const total = installments.reduce((t, i) => t + i.amount, 0);
    const paid = sum('PAID');

    return {
      summary: {
        total,
        paid,
        pending: sum('PENDING'),
        upcoming: sum('UPCOMING'),
        // What the parent still owes — everything not yet paid.
        due: total - paid,
      },
      installments: installments.map((i) => ({
        id: i.id,
        label: i.label,
        amount: i.amount,
        dueDate: i.dueDate,
        status: i.status,
        term: i.assignment.feeStructure.termLabel,
        paidAt: i.payments[0]?.paidAt ?? null,
      })),
    };
  }

  /** Full marks list, newest term first. */
  async marks(userId: string) {
    const student = await this.childFor(userId);
    const marks = await this.prisma.mark.findMany({
      where: { studentId: student.id },
      include: { subject: true },
      orderBy: { termLabel: 'desc' },
    });

    return marks.map((m) => ({
      id: m.id,
      subject: m.subject.name,
      termLabel: m.termLabel,
      marks: m.marks,
      maxMarks: m.maxMarks,
      grade: m.grade,
      remarks: m.remarks,
      percent: m.maxMarks > 0 ? Math.round((m.marks / m.maxMarks) * 100) : 0,
    }));
  }
}
