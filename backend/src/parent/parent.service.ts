import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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
    const unreadNotifications = await this.prisma.appNotification.count({
      where: { userId, readAt: null },
    });

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
      recentAttendance,
      feePayments,
      feeInstallments,
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
      // Dated activity sources — attendance days and fee payments. Marks carry
      // no timestamp, so they can't join a time-ordered feed.
      this.prisma.attendanceRecord.findMany({
        where: { studentId: student.id },
        orderBy: { date: 'desc' },
        take: 8,
        select: { id: true, date: true, status: true },
      }),
      this.prisma.feePayment.findMany({
        where: { installment: { assignment: { studentId: student.id } } },
        orderBy: { paidAt: 'desc' },
        take: 5,
        include: { installment: { select: { label: true } } },
      }),
      this.prisma.feeInstallment.findMany({
        where: { assignment: { studentId: student.id } },
        select: { amount: true, status: true },
      }),
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

    // Fee summary for the home tile (full breakdown lives on /parent/fees).
    const feeTotal = feeInstallments.reduce((t, i) => t + i.amount, 0);
    const feePaid = feeInstallments
      .filter((i) => i.status === 'PAID')
      .reduce((t, i) => t + i.amount, 0);

    // Merge dated events into one recent-activity feed, newest first.
    const activity = [
      ...recentAttendance.map((a) => ({
        id: a.id,
        type: 'attendance' as const,
        status: a.status,
        label: null as string | null,
        date: a.date,
      })),
      ...feePayments.map((p) => ({
        id: p.id,
        type: 'fee' as const,
        status: null,
        label: p.installment.label,
        date: p.paidAt,
      })),
    ]
      .sort((x, y) => new Date(y.date).getTime() - new Date(x.date).getTime())
      .slice(0, 6);

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
      fees: {
        total: feeTotal,
        paid: feePaid,
        due: feeTotal - feePaid,
      },
      activity,
      homework: homework.map((h) => ({
        id: h.id,
        title: h.title,
        description: h.description,
        dueDate: h.dueDate,
      })),
      upcomingTests,
      unreadNotifications,
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

  /** Upcoming school events for the child's school (today onward). */
  async events(userId: string) {
    const student = await this.childFor(userId);
    const schoolId = student.class?.schoolId;
    if (!schoolId) return [];
    const from = new Date();
    from.setHours(0, 0, 0, 0);
    return this.prisma.event.findMany({
      where: { schoolId, startAt: { gte: from } },
      orderBy: { startAt: 'asc' },
      take: 50,
    });
  }

  /** Upcoming homework for the child's class. */
  async homework(userId: string) {
    const student = await this.childFor(userId);
    const homework = await this.prisma.homework.findMany({
      where: { classId: student.classId, dueDate: { gte: new Date() } },
      orderBy: { dueDate: 'asc' },
      include: { teacher: { include: { user: true } } },
      take: 50,
    });
    return homework.map((h) => ({
      id: h.id,
      title: h.title,
      description: h.description,
      dueDate: h.dueDate,
      teacher: h.teacher?.user.fullName ?? null,
    }));
  }

  /** Books the child has borrowed — current (with overdue flag) and history. */
  async library(userId: string) {
    const student = await this.childFor(userId);
    const issues = await this.prisma.bookIssue.findMany({
      where: { studentId: student.id },
      orderBy: [{ returnedAt: 'asc' }, { dueDate: 'asc' }],
      include: { book: true },
    });

    const now = new Date();
    return issues.map((i) => ({
      id: i.id,
      title: i.book.title,
      author: i.book.author,
      category: i.book.category,
      issuedAt: i.issuedAt,
      dueDate: i.dueDate,
      returnedAt: i.returnedAt,
      overdue: i.returnedAt == null && i.dueDate < now,
    }));
  }

  // ---- Leave applications ----

  async listLeaves(userId: string) {
    const student = await this.childFor(userId);
    const leaves = await this.prisma.leaveRequest.findMany({
      where: { studentId: student.id },
      orderBy: { createdAt: 'desc' },
      include: { reviewedBy: { include: { user: true } } },
    });
    return leaves.map((l) => ({
      id: l.id,
      fromDate: l.fromDate,
      toDate: l.toDate,
      reason: l.reason,
      status: l.status,
      reviewNote: l.reviewNote,
      reviewedBy: l.reviewedBy?.user.fullName ?? null,
      reviewedAt: l.reviewedAt,
      createdAt: l.createdAt,
    }));
  }

  async createLeave(
    userId: string,
    dto: { fromDate: string; toDate: string; reason: string },
  ) {
    const student = await this.childFor(userId);

    const from = ParentService.dateOnly(dto.fromDate);
    const to = ParentService.dateOnly(dto.toDate);
    if (to < from) {
      throw new BadRequestException('End date cannot be before start date');
    }
    const reason = dto.reason?.trim();
    if (!reason) throw new BadRequestException('Reason is required');

    const leave = await this.prisma.leaveRequest.create({
      data: {
        studentId: student.id,
        requestedByUserId: userId,
        fromDate: from,
        toDate: to,
        reason,
      },
    });

    // Tell the class teacher a request is waiting.
    const teacherUserId = student.class?.classTeacher?.userId;
    if (teacherUserId) {
      await this.prisma.appNotification.create({
        data: {
          userId: teacherUserId,
          title: `Leave request for ${student.fullName}`,
          body: reason.length > 120 ? `${reason.slice(0, 117)}…` : reason,
        },
      });
    }

    return leave;
  }

  private static dateOnly(input: string): Date {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(input?.trim() ?? '');
    if (!m) throw new BadRequestException('Invalid date (expected YYYY-MM-DD)');
    return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  }

  // ---- Notifications (chat messages, announcements) ----

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

  async markAllNotificationsRead(userId: string) {
    await this.prisma.appNotification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  }

  private static gradeFor(pct: number): string {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 35) return 'D';
    return 'F';
  }

  /**
   * Report cards built from the child's marks, one per exam term. Includes the
   * total, percentage, overall grade, pass/fail, and the child's rank in class
   * for that term.
   */
  async reportCards(userId: string) {
    const student = await this.childFor(userId);
    const classId = student.classId;
    const schoolId = student.class?.schoolId;

    const [marks, school, classMarks] = await Promise.all([
      this.prisma.mark.findMany({
        where: { studentId: student.id },
        include: { subject: true },
        orderBy: { termLabel: 'desc' },
      }),
      schoolId
        ? this.prisma.school.findUnique({
            where: { id: schoolId },
            select: { name: true },
          })
        : Promise.resolve(null),
      // Every mark in the class, for ranking.
      this.prisma.mark.findMany({
        where: { student: { classId } },
        select: {
          studentId: true,
          termLabel: true,
          marks: true,
          maxMarks: true,
        },
      }),
    ]);

    // term -> studentId -> { obtained, max }, so rank can be computed on
    // percentage rather than a raw marks sum (which unfairly penalises students
    // who have fewer subjects graded, or with different maxMarks).
    type Totals = { obtained: number; max: number };
    const termTotals = new Map<string, Map<string, Totals>>();
    for (const m of classMarks) {
      const perStudent = termTotals.get(m.termLabel) ?? new Map<string, Totals>();
      const acc = perStudent.get(m.studentId) ?? { obtained: 0, max: 0 };
      acc.obtained += m.marks;
      acc.max += m.maxMarks;
      perStudent.set(m.studentId, acc);
      termTotals.set(m.termLabel, perStudent);
    }
    const pctOf = (t: Totals) => (t.max > 0 ? t.obtained / t.max : 0);

    // Group the child's marks by term.
    const byTerm = new Map<string, typeof marks>();
    for (const m of marks) {
      byTerm.set(m.termLabel, [...(byTerm.get(m.termLabel) ?? []), m]);
    }

    const cards = [...byTerm.entries()].map(([term, rows]) => {
      const subjects = rows.map((m) => ({
        subject: m.subject.name,
        marks: m.marks,
        maxMarks: m.maxMarks,
        grade: m.grade,
        percent:
          m.maxMarks > 0 ? Math.round((m.marks / m.maxMarks) * 100) : 0,
      }));
      const totalObtained = subjects.reduce((s, x) => s + x.marks, 0);
      const totalMax = subjects.reduce((s, x) => s + x.maxMarks, 0);
      const percentage =
        totalMax > 0 ? Math.round((totalObtained / totalMax) * 100) : 0;

      // Rank: order classmates by their percentage for this term. Rank is
      // 1 + the number of classmates strictly ahead, so ties share a rank.
      const perStudent = termTotals.get(term);
      let rank: number | null = null;
      let classSize: number | null = null;
      if (perStudent) {
        const percentages = [...perStudent.values()].map(pctOf);
        classSize = percentages.length;
        const mineTotals = perStudent.get(student.id);
        const minePct = mineTotals
          ? pctOf(mineTotals)
          : totalMax > 0
            ? totalObtained / totalMax
            : 0;
        rank = percentages.filter((p) => p > minePct + 1e-9).length + 1;
      }

      return {
        term,
        subjects,
        totalObtained,
        totalMax,
        percentage,
        overallGrade: ParentService.gradeFor(percentage),
        result: subjects.every((s) => s.percent >= 35) ? 'PASS' : 'FAIL',
        rank,
        classSize,
      };
    });

    return {
      child: {
        fullName: student.fullName,
        rollNumber: student.rollNumber,
        className: student.class?.name ?? '',
        studentCode: student.studentCode,
        schoolName: school?.name ?? '',
      },
      cards,
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
