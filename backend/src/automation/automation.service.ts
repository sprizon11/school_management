import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AttendanceStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type Note = {
  userId: string;
  title: string;
  body: string;
  dedupeKey: string;
};

/**
 * The "works while you sleep" layer. A daily job derives reminders from data
 * teachers and admins already entered — fees, attendance, homework, events,
 * library, birthdays — and pushes them to the right people. Every reminder
 * carries a dedupeKey so re-runs never double-send.
 */
@Injectable()
export class AutomationService {
  private readonly log = new Logger(AutomationService.name);

  constructor(private prisma: PrismaService) {}

  // 7:00 AM every day, in the schools' timezone. Without an explicit zone the
  // job would fire at 07:00 UTC (12:30 PM IST) on Cloud Run, not local morning.
  @Cron(CronExpression.EVERY_DAY_AT_7AM, { timeZone: 'Asia/Kolkata' })
  async scheduled() {
    const summary = await this.runDaily();
    this.log.log(`Daily reminders sent: ${JSON.stringify(summary)}`);
  }

  /** Runs every rule and returns how many notifications each produced. */
  async runDaily() {
    const [fees, attendance, homework, events, library, birthdays] =
      await Promise.all([
        this.feeReminders(),
        this.lowAttendance(),
        this.homeworkDueTomorrow(),
        this.eventsTomorrow(),
        this.libraryOverdue(),
        this.birthdays(),
      ]);
    return { fees, attendance, homework, events, library, birthdays };
  }

  private async push(items: Note[]): Promise<number> {
    if (items.length === 0) return 0;
    const res = await this.prisma.appNotification.createMany({
      data: items,
      skipDuplicates: true, // the unique dedupeKey does the de-duplication
    });
    return res.count;
  }

  private static startOfDay(d = new Date()): Date {
    const x = new Date(d);
    x.setHours(0, 0, 0, 0);
    return x;
  }

  private static money(n: number): string {
    // The local dev DB is WIN1252-encoded and can't store the ₹ glyph, so
    // notification text uses "Rs" to stay Latin-1 safe.
    const s = n.toString();
    if (s.length <= 3) return `Rs ${s}`;
    const head = s.slice(0, -3);
    const tail = s.slice(-3);
    return `Rs ${head.replace(/(\d)(?=(\d\d)+$)/g, '$1,')},${tail}`;
  }

  // ---- Rules ----

  /** Fee installments due within 4 days, and overdue ones. */
  private async feeReminders(): Promise<number> {
    const today = AutomationService.startOfDay();
    const soon = new Date(today.getTime() + 4 * 86400000);

    const installments = await this.prisma.feeInstallment.findMany({
      where: {
        status: { in: ['PENDING', 'UPCOMING'] },
        dueDate: { lt: soon },
      },
      include: {
        assignment: {
          include: { student: { include: { parent: true } } },
        },
      },
    });

    const notes: Note[] = [];
    for (const i of installments) {
      const parent = i.assignment.student.parent;
      if (!parent) continue;
      const overdue = i.dueDate < today;
      notes.push({
        userId: parent.userId,
        title: overdue
          ? `Fee overdue: ${i.label}`
          : `Fee due soon: ${i.label}`,
        body: overdue
          ? `${AutomationService.money(i.amount)} for ${i.label} is overdue. Please pay to avoid late charges.`
          : `${AutomationService.money(i.amount)} for ${i.label} is due on ${i.dueDate.toISOString().slice(0, 10)}.`,
        dedupeKey: overdue ? `fee-overdue-${i.id}` : `fee-due-${i.id}`,
      });
    }
    return this.push(notes);
  }

  /**
   * Students whose attendance has dropped below 75% over a rolling recent
   * window (re-warns monthly). The window keeps the daily aggregate bounded as
   * the table grows, and means a rough early stretch stops flagging a student
   * who now attends regularly, rather than counting against them for all time.
   */
  private static readonly ATTENDANCE_WINDOW_DAYS = 120;

  private async lowAttendance(): Promise<number> {
    const windowStart = new Date(
      AutomationService.startOfDay().getTime() -
        AutomationService.ATTENDANCE_WINDOW_DAYS * 86400000,
    );
    const grouped = await this.prisma.attendanceRecord.groupBy({
      by: ['studentId', 'status'],
      where: { date: { gte: windowStart } },
      _count: { _all: true },
    });

    const stats = new Map<
      string,
      { present: number; absent: number; leave: number }
    >();
    for (const g of grouped) {
      const s = stats.get(g.studentId) ?? { present: 0, absent: 0, leave: 0 };
      if (g.status === AttendanceStatus.PRESENT) s.present = g._count._all;
      else if (g.status === AttendanceStatus.ABSENT) s.absent = g._count._all;
      else s.leave = g._count._all;
      stats.set(g.studentId, s);
    }

    const flagged: string[] = [];
    for (const [studentId, s] of stats) {
      const marked = s.present + s.absent + s.leave;
      if (marked < 5) continue;
      const pct = Math.round(((s.present + s.leave) / marked) * 100);
      if (pct < 75) flagged.push(studentId);
    }
    if (flagged.length === 0) return 0;

    const parents = await this.prisma.parent.findMany({
      where: { studentId: { in: flagged } },
      include: { student: { select: { id: true, fullName: true } } },
    });

    const month = new Date().toISOString().slice(0, 7);
    const notes: Note[] = parents.map((p) => ({
      userId: p.userId,
      title: `Low attendance: ${p.student.fullName}`,
      body: `${p.student.fullName}'s attendance has fallen below 75%. Please ensure regular attendance.`,
      dedupeKey: `low-att-${p.student.id}-${month}`,
    }));
    return this.push(notes);
  }

  /** Homework due tomorrow → parents of that class. */
  private async homeworkDueTomorrow(): Promise<number> {
    const start = new Date(
      AutomationService.startOfDay().getTime() + 86400000,
    );
    const end = new Date(start.getTime() + 86400000);

    const homework = await this.prisma.homework.findMany({
      where: { dueDate: { gte: start, lt: end } },
      include: {
        class: {
          include: { students: { include: { parent: true } } },
        },
      },
    });

    const notes: Note[] = [];
    for (const h of homework) {
      for (const student of h.class.students) {
        if (!student.parent) continue;
        notes.push({
          userId: student.parent.userId,
          title: `Homework due tomorrow`,
          body: `"${h.title}" is due tomorrow.`,
          dedupeKey: `hw-due-${h.id}-${student.id}`,
        });
      }
    }
    return this.push(notes);
  }

  /** School events happening tomorrow → all parents in that school. */
  private async eventsTomorrow(): Promise<number> {
    const start = new Date(
      AutomationService.startOfDay().getTime() + 86400000,
    );
    const end = new Date(start.getTime() + 86400000);

    const events = await this.prisma.event.findMany({
      where: { startAt: { gte: start, lt: end } },
    });
    if (events.length === 0) return 0;

    const notes: Note[] = [];
    for (const e of events) {
      const parents = await this.prisma.parent.findMany({
        where: { student: { class: { schoolId: e.schoolId } } },
        select: { userId: true, id: true },
      });
      for (const p of parents) {
        notes.push({
          userId: p.userId,
          title: `Tomorrow: ${e.title}`,
          body: `${e.category} — ${e.title}${e.location ? ` at ${e.location}` : ''}.`,
          dedupeKey: `event-${e.id}-${p.id}`,
        });
      }
    }
    return this.push(notes);
  }

  /** Library books past their due date and not returned. */
  private async libraryOverdue(): Promise<number> {
    const today = AutomationService.startOfDay();
    const issues = await this.prisma.bookIssue.findMany({
      where: { returnedAt: null, dueDate: { lt: today } },
      include: {
        book: { select: { title: true } },
        student: { include: { parent: true } },
      },
    });

    const notes: Note[] = [];
    for (const i of issues) {
      if (!i.student.parent) continue;
      notes.push({
        userId: i.student.parent.userId,
        title: `Library book overdue`,
        body: `"${i.book.title}" was due on ${i.dueDate.toISOString().slice(0, 10)}. Please return it.`,
        dedupeKey: `lib-overdue-${i.id}`,
      });
    }
    return this.push(notes);
  }

  /** Students with a birthday today → class teacher (and parent gets a wish). */
  private async birthdays(): Promise<number> {
    const students = await this.prisma.student.findMany({
      where: { status: 'ACTIVE', dateOfBirth: { not: null } },
      include: {
        parent: true,
        class: { include: { classTeacher: { select: { userId: true } } } },
      },
    });

    const now = new Date();
    const year = now.getFullYear();
    const notes: Note[] = [];
    for (const s of students) {
      const dob = s.dateOfBirth!;
      if (dob.getMonth() !== now.getMonth() || dob.getDate() !== now.getDate())
        continue;

      const teacherUserId = s.class?.classTeacher?.userId;
      if (teacherUserId) {
        notes.push({
          userId: teacherUserId,
          title: `${s.fullName} has a birthday today`,
          body: `It's ${s.fullName}'s birthday. A wish would make their day!`,
          dedupeKey: `bday-teacher-${s.id}-${year}`,
        });
      }
      if (s.parent) {
        notes.push({
          userId: s.parent.userId,
          title: `Happy Birthday, ${s.fullName}!`,
          body: `The whole school wishes ${s.fullName} a wonderful birthday.`,
          dedupeKey: `bday-parent-${s.id}-${year}`,
        });
      }
    }
    return this.push(notes);
  }
}
