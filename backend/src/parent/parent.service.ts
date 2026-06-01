import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ParentService {
  constructor(private prisma: PrismaService) {}

  async assertStudentAccess(parentId: string, studentId: string) {
    const link = await this.prisma.parentStudent.findFirst({
      where: { parentId, studentId },
    });
    if (!link) throw new ForbiddenException('Not your child');
  }

  async children(parentId: string) {
    const links = await this.prisma.parentStudent.findMany({
      where: { parentId },
      include: { student: { include: { class: true } } },
    });
    return links.map((l) => ({
      id: l.student.id,
      fullName: l.student.fullName,
      rollNumber: l.student.rollNumber,
      className: `${l.student.class.grade}${l.student.class.section}`,
      grade: l.student.class.grade,
      section: l.student.class.section,
      avatarUrl: l.student.avatarUrl,
      status: l.student.status,
    }));
  }

  async getStudent(studentId: string) {
    return this.prisma.student.findUnique({
      where: { id: studentId },
      include: { class: { include: { school: true } } },
    });
  }

  async dashboardSummary(studentId: string) {
    const student = await this.getStudent(studentId);
    if (!student) throw new NotFoundException('Student not found');

    const termStart = new Date();
    termStart.setMonth(termStart.getMonth() - 3);
    const [present, total] = await Promise.all([
      this.prisma.attendanceRecord.count({
        where: { studentId, status: 'PRESENT', date: { gte: termStart } },
      }),
      this.prisma.attendanceRecord.count({
        where: { studentId, date: { gte: termStart } },
      }),
    ]);
    const marks = await this.prisma.mark.findMany({
      where: { studentId, termLabel: 'Apr-Jun 2024' },
    });
    const avg =
      marks.length > 0
        ? marks.reduce((s, m) => s + (m.marks / m.maxMarks) * 100, 0) /
          marks.length
        : 85;

    return {
      student: {
        id: student.id,
        fullName: student.fullName,
        rollNumber: student.rollNumber,
        className: `Class ${student.class.grade}${student.class.section}`,
      },
      attendancePercent: total > 0 ? Math.round((present / total) * 100) : 92,
      averageGrade: avg >= 90 ? 'A' : avg >= 80 ? 'B' : 'C',
      averagePercent: Math.round(avg),
      assignmentsSubmitted: 5,
      assignmentsTotal: 6,
      leaveRequestsPending: 0,
    };
  }

  async announcements(limit = 5) {
    return this.prisma.announcement.findMany({
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async events() {
    return this.prisma.event.findMany({
      where: { startAt: { gte: new Date() } },
      orderBy: { startAt: 'asc' },
      take: 8,
    });
  }

  async performanceBySubject(studentId: string) {
    const marks = await this.prisma.mark.findMany({
      where: { studentId, termLabel: 'Apr-Jun 2024' },
      include: { subject: true },
    });
    return marks.map((m) => ({
      subject: m.subject.name,
      percent: Math.round((m.marks / m.maxMarks) * 100),
    }));
  }

  async attendanceSummary(studentId: string) {
    const records = await this.prisma.attendanceRecord.findMany({
      where: { studentId },
    });
    const present = records.filter((r) => r.status === 'PRESENT').length;
    const absent = records.filter((r) => r.status === 'ABSENT').length;
    const leave = records.filter((r) => r.status === 'LEAVE').length;
    const total = records.length || 1;
    return {
      presentDays: present,
      absentDays: absent,
      leaveDays: leave,
      totalPercent: Math.round((present / total) * 100),
    };
  }

  async attendanceCalendar(studentId: string, year: number, month: number) {
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);
    const records = await this.prisma.attendanceRecord.findMany({
      where: { studentId, date: { gte: start, lte: end } },
    });
    return records.map((r) => ({
      date: r.date.toISOString().split('T')[0],
      status: r.status,
    }));
  }

  async attendanceRecent(studentId: string, limit = 5) {
    return this.prisma.attendanceRecord.findMany({
      where: { studentId },
      orderBy: { date: 'desc' },
      take: limit,
    });
  }

  async attendanceTrend(studentId: string) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
    return months.map((m, i) => ({
      month: m,
      percent: 94 + (i % 3) - 1,
    }));
  }

  async resultsSummary(studentId: string) {
    const marks = await this.prisma.mark.findMany({
      where: { studentId, termLabel: 'Apr-Jun 2024' },
      include: { subject: true },
    });
    const percents = marks.map((m) => (m.marks / m.maxMarks) * 100);
    const avg =
      percents.length > 0
        ? percents.reduce((a, b) => a + b, 0) / percents.length
        : 85;
    const passed = percents.filter((p) => p >= 50).length;
    return {
      overallGrade: avg >= 90 ? 'A' : 'B+',
      overallPercent: Math.round(avg),
      subjectsPassed: passed,
      subjectsTotal: marks.length || 6,
      subjectsFailed: 0,
      subjectsAverage: 1,
    };
  }

  async resultsMarks(studentId: string) {
    return this.prisma.mark.findMany({
      where: { studentId, termLabel: 'Apr-Jun 2024' },
      include: { subject: true },
    });
  }

  async gradeHistory(studentId: string) {
    return [
      { term: 'Oct-Dec 2023', percent: 78 },
      { term: 'Jan-Mar 2024', percent: 82 },
      { term: 'Apr-Jun 2024', percent: 85 },
    ];
  }

  async teacherRemarks(studentId: string) {
    return {
      text: 'Aryan is performing very well in most subjects. Keep up the good work and continue to stay focused in English.',
      teacherName: 'Mr. Sharma',
      role: 'Class Teacher',
    };
  }

  async feesSummary(studentId: string) {
    const assignment = await this.prisma.feeAssignment.findFirst({
      where: { studentId },
      include: { feeStructure: true, installments: true },
    });
    if (!assignment) {
      return {
        feeCode: 'FEE000000',
        total: 36000,
        paid: 27000,
        pending: 9000,
        dueDate: '2024-06-15',
        daysLeft: 15,
      };
    }
    const paid = await this.prisma.feePayment.aggregate({
      where: { installment: { assignmentId: assignment.id } },
      _sum: { amount: true },
    });
    const total = assignment.feeStructure.totalAmount;
    const paidAmt = paid._sum.amount ?? 0;
    return {
      feeCode: assignment.feeCode,
      total,
      paid: paidAmt,
      pending: total - paidAmt,
      dueDate: assignment.installments.find((i) => i.status === 'PENDING')
        ?.dueDate,
      daysLeft: 15,
    };
  }

  async feesInstallments(studentId: string) {
    const assignment = await this.prisma.feeAssignment.findFirst({
      where: { studentId },
      include: { installments: { include: { payments: true } } },
    });
    return assignment?.installments ?? [];
  }

  async feesPayments(studentId: string) {
    const assignment = await this.prisma.feeAssignment.findFirst({
      where: { studentId },
    });
    if (!assignment) return [];
    return this.prisma.feePayment.findMany({
      where: { installment: { assignmentId: assignment.id } },
      include: { installment: true },
      orderBy: { paidAt: 'desc' },
      take: 5,
    });
  }

  async feesBreakdown(studentId: string) {
    return [
      { label: 'Tuition Fee', amount: 28000 },
      { label: 'Development Fee', amount: 5000 },
      { label: 'Lab Fee', amount: 2000 },
      { label: 'Activity Fee', amount: 1000 },
    ];
  }

  async profile(parentId: string) {
    return this.prisma.parent.findUnique({
      where: { id: parentId },
      include: {
        user: true,
        children: { include: { student: { include: { class: true } } } },
      },
    });
  }
}
