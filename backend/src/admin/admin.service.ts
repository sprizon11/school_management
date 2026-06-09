import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AnnouncementAudience,
  Prisma,
  StudentStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CreateClassDto } from './dto/create-class.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { CreateTeacherDto } from './dto/create-teacher.dto';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import {
  isSeniorGrade,
  normalizeStreamGroup,
  SENIOR_STREAM_GROUPS,
  validateStreamGroupForGrade,
} from './senior-stream-groups';
import { UpdateSchoolProfileDto } from './dto/update-school-profile.dto';
import { UpdateStudentDto } from './dto/update-student.dto';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  private async resolveSchoolId() {
    let school = await this.prisma.school.findFirst({
      where: { isActive: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!school) {
      school = await this.prisma.school.create({
        data: {
          name: 'My School',
          code: `school-${Date.now()}`,
          isActive: true,
        },
      });
    }
    return school.id;
  }

  async dashboardSummary(schoolId: string) {
    const [students, teachers, classes, paid, totalFees, boys, girls, maleTeachers, femaleTeachers] =
      await Promise.all([
      this.prisma.student.count({ where: { status: StudentStatus.ACTIVE } }),
      this.prisma.teacher.count(),
      this.prisma.class.count(),
      this.prisma.feePayment.aggregate({ _sum: { amount: true } }),
      this.prisma.feeStructure.aggregate({ _sum: { totalAmount: true } }),
      this.prisma.student.count({
        where: { status: StudentStatus.ACTIVE, gender: 'MALE' },
      }),
      this.prisma.student.count({
        where: { status: StudentStatus.ACTIVE, gender: 'FEMALE' },
      }),
      this.prisma.teacher.count({ where: { gender: 'MALE' } }),
      this.prisma.teacher.count({ where: { gender: 'FEMALE' } }),
    ]);

    const monthAgo = new Date();
    monthAgo.setMonth(monthAgo.getMonth() - 1);
    const present = await this.prisma.attendanceRecord.count({
      where: {
        status: 'PRESENT',
        date: { gte: monthAgo },
      },
    });
    const totalAtt = await this.prisma.attendanceRecord.count({
      where: { date: { gte: monthAgo } },
    });

    const [announcements, activities, recentTransactions, topStudents] =
      await Promise.all([
        this.prisma.announcement.findMany({
          where: { schoolId },
          orderBy: { createdAt: 'desc' },
          take: 5,
        }),
        this.prisma.activityLog.findMany({
          orderBy: { createdAt: 'desc' },
          take: 10,
        }),
        this.recentFeeTransactions(schoolId),
        this.topStudentsByGrade(schoolId),
      ]);

    return {
      students: { count: students, boys, girls },
      teachers: {
        count: teachers,
        male: maleTeachers,
        female: femaleTeachers,
      },
      classes: { count: classes, students },
      feeCollection: {
        amount: paid._sum.amount ?? 0,
        total: (totalFees._sum.totalAmount ?? 0) * students,
      },
      attendancePercent:
        totalAtt > 0 ? Math.round((present / totalAtt) * 100) : 0,
      announcements,
      activities,
      recentTransactions,
      topStudents,
    };
  }

  private async recentFeeTransactions(schoolId: string) {
    const payments = await this.prisma.feePayment.findMany({
      take: 6,
      orderBy: { paidAt: 'desc' },
      where: {
        installment: {
          assignment: {
            student: {
              class: { schoolId },
            },
          },
        },
      },
      include: {
        installment: {
          include: {
            assignment: {
              include: {
                student: {
                  include: { class: true },
                },
              },
            },
          },
        },
      },
    });

    return payments.map((p) => {
      const student = p.installment.assignment.student;
      const method = p.method || 'Online Payment';
      return {
        id: p.id,
        studentName: student.fullName,
        className: student.class.name,
        grade: student.class.grade,
        amount: p.amount,
        method,
        paidAt: p.paidAt,
        description: `${student.fullName} paid fee online via ${method}`,
      };
    });
  }

  getSeniorStreamGroups() {
    return SENIOR_STREAM_GROUPS;
  }

  private rankStudents(
    students: Array<{
      id: string;
      fullName: string;
      rollNumber: number;
      marks: { marks: number; maxMarks: number }[];
      class: {
        grade: number;
        section: string;
        name: string;
        streamGroup: string;
      };
    }>,
    grade: number,
  ) {
    return students
      .map((s) => {
        if (s.marks.length === 0) return null;
        const scored = s.marks.reduce((sum, m) => sum + m.marks, 0);
        const maxTotal = s.marks.reduce((sum, m) => sum + m.maxMarks, 0);
        const averagePercent =
          maxTotal > 0 ? Math.round((scored / maxTotal) * 1000) / 10 : 0;
        const groupSuffix =
          s.class.streamGroup && s.class.streamGroup.length > 0
            ? ` · ${s.class.streamGroup}`
            : '';
        return {
          studentId: s.id,
          fullName: s.fullName,
          rollNumber: s.rollNumber,
          classLabel: `${s.class.name} · ${grade}${s.class.section}${groupSuffix}`,
          grade,
          streamGroup: s.class.streamGroup || null,
          averagePercent,
        };
      })
      .filter((s): s is NonNullable<typeof s> => s !== null)
      .sort((a, b) => b.averagePercent - a.averagePercent)
      .slice(0, 5)
      .map((s, index) => ({ ...s, rank: index + 1 }));
  }

  private async topStudentsByGrade(schoolId: string) {
    const grade10Students = await this.prisma.student.findMany({
      where: {
        status: StudentStatus.ACTIVE,
        class: { grade: 10, schoolId },
      },
      include: {
        class: {
          select: { grade: true, section: true, name: true, streamGroup: true },
        },
        marks: { select: { marks: true, maxMarks: true } },
      },
    });

    const blocks: Array<{
      grade: number;
      label: string;
      streamGroup?: string | null;
      students: ReturnType<AdminService['rankStudents']>;
    }> = [
      {
        grade: 10,
        label: '10th Standard',
        students: this.rankStudents(grade10Students, 10),
      },
    ];

    for (const grade of [11, 12]) {
      for (const streamGroup of SENIOR_STREAM_GROUPS) {
        const students = await this.prisma.student.findMany({
          where: {
            status: StudentStatus.ACTIVE,
            class: { grade, schoolId, streamGroup },
          },
          include: {
            class: {
              select: {
                grade: true,
                section: true,
                name: true,
                streamGroup: true,
              },
            },
            marks: { select: { marks: true, maxMarks: true } },
          },
        });

        if (students.length === 0) continue;

        const ranked = this.rankStudents(students, grade);
        if (ranked.length === 0) continue;

        blocks.push({
          grade,
          streamGroup,
          label: `${grade}th · ${streamGroup}`,
          students: ranked,
        });
      }
    }

    return blocks;
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

  async getStudent(id: string) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: {
        class: {
          include: {
            classTeacher: { include: { user: true } },
          },
        },
      },
    });
    if (!student) throw new NotFoundException('Student not found');

    const monthAgo = new Date();
    monthAgo.setMonth(monthAgo.getMonth() - 1);
    const [presentDays, totalDays] = await Promise.all([
      this.prisma.attendanceRecord.count({
        where: {
          studentId: id,
          status: 'PRESENT',
          date: { gte: monthAgo },
        },
      }),
      this.prisma.attendanceRecord.count({
        where: { studentId: id, date: { gte: monthAgo } },
      }),
    ]);

    return {
      id: student.id,
      fullName: student.fullName,
      studentCode: student.studentCode,
      email: student.email,
      phone: student.phone,
      gender: student.gender,
      rollNumber: student.rollNumber,
      dateOfBirth: student.dateOfBirth,
      bloodGroup: student.bloodGroup,
      address: student.address,
      status: student.status,
      avatarUrl: student.avatarUrl,
      fatherName: student.fatherName,
      fatherPhone: student.fatherPhone,
      fatherOccupation: student.fatherOccupation,
      motherName: student.motherName,
      motherPhone: student.motherPhone,
      motherOccupation: student.motherOccupation,
      parentAddress: student.parentAddress,
      emergencyContact: student.emergencyContact,
      emergencyPhone: student.emergencyPhone,
      classId: student.classId,
      grade: student.class.grade,
      section: student.class.section,
      className: student.class.name,
      classTeacher: student.class.classTeacher
        ? {
            name: student.class.classTeacher.user.fullName,
            phone: student.class.classTeacher.user.phone,
            department: student.class.classTeacher.department,
          }
        : null,
      attendancePercent:
        totalDays > 0 ? Math.round((presentDays / totalDays) * 100) : null,
      createdAt: student.createdAt,
    };
  }

  async updateStudent(id: string, dto: UpdateStudentDto) {
    const existing = await this.prisma.student.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Student not found');

    if (dto.classId) {
      const cls = await this.prisma.class.findUnique({ where: { id: dto.classId } });
      if (!cls) throw new BadRequestException('Class not found');
    }

    const data: Prisma.StudentUpdateInput = {};
    if (dto.fullName !== undefined) data.fullName = dto.fullName.trim();
    if (dto.gender !== undefined) data.gender = dto.gender;
    if (dto.classId !== undefined) data.class = { connect: { id: dto.classId } };
    if (dto.email !== undefined) data.email = dto.email.trim().toLowerCase() || null;
    if (dto.phone !== undefined) data.phone = dto.phone.trim() || null;
    if (dto.rollNumber !== undefined) data.rollNumber = dto.rollNumber;
    if (dto.dateOfBirth !== undefined) {
      data.dateOfBirth = dto.dateOfBirth ? new Date(dto.dateOfBirth) : null;
    }
    if (dto.bloodGroup !== undefined) data.bloodGroup = dto.bloodGroup.trim() || null;
    if (dto.address !== undefined) data.address = dto.address.trim() || null;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl || null;
    if (dto.fatherName !== undefined) data.fatherName = dto.fatherName.trim() || null;
    if (dto.fatherPhone !== undefined) data.fatherPhone = dto.fatherPhone.trim() || null;
    if (dto.fatherOccupation !== undefined) {
      data.fatherOccupation = dto.fatherOccupation.trim() || null;
    }
    if (dto.motherName !== undefined) data.motherName = dto.motherName.trim() || null;
    if (dto.motherPhone !== undefined) data.motherPhone = dto.motherPhone.trim() || null;
    if (dto.motherOccupation !== undefined) {
      data.motherOccupation = dto.motherOccupation.trim() || null;
    }
    if (dto.parentAddress !== undefined) data.parentAddress = dto.parentAddress.trim() || null;
    if (dto.emergencyContact !== undefined) {
      data.emergencyContact = dto.emergencyContact.trim() || null;
    }
    if (dto.emergencyPhone !== undefined) data.emergencyPhone = dto.emergencyPhone.trim() || null;
    if (dto.status !== undefined) data.status = dto.status;

    await this.prisma.student.update({ where: { id }, data });

    await this.prisma.activityLog.create({
      data: {
        action: `Updated student ${dto.fullName ?? existing.fullName}`,
        actorName: 'Admin',
      },
    });

    return this.getStudent(id);
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

  async teacherStats(schoolId: string) {
    const schoolFilter = { user: { schoolId } };
    const [total, male, female, newMonth] = await Promise.all([
      this.prisma.teacher.count({ where: schoolFilter }),
      this.prisma.teacher.count({ where: { ...schoolFilter, gender: 'MALE' } }),
      this.prisma.teacher.count({
        where: { ...schoolFilter, gender: 'FEMALE' },
      }),
      this.prisma.teacher.count({
        where: {
          ...schoolFilter,
          user: {
            schoolId,
            createdAt: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
          },
        },
      }),
    ]);
    return {
      total,
      male,
      female,
      malePercent: total ? Math.round((male / total) * 1000) / 10 : 0,
      femalePercent: total ? Math.round((female / total) * 1000) / 10 : 0,
      newThisMonth: newMonth,
    };
  }

  async listTeachers(
    schoolId: string,
    params: { page?: number; limit?: number; search?: string },
  ) {
    const page = params.page ?? 1;
    const limit = params.limit ?? 10;
    const where: Prisma.TeacherWhereInput = { user: { schoolId } };
    if (params.search) {
      where.OR = [
        {
          user: {
            fullName: { contains: params.search, mode: 'insensitive' },
          },
        },
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
        gender: t.gender,
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

  async deleteTeacher(schoolId: string, id: string) {
    const teacher = await this.prisma.teacher.findUnique({
      where: { id },
      include: { user: true },
    });
    if (!teacher) {
      throw new NotFoundException('Teacher not found');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.class.updateMany({
        where: { classTeacherId: id },
        data: { classTeacherId: null },
      });
      await tx.mark.updateMany({
        where: { teacherId: id },
        data: { teacherId: null },
      });
      await tx.homework.deleteMany({ where: { teacherId: id } });
      await tx.teacher.delete({ where: { id } });
      await tx.user.delete({ where: { id: teacher.userId } });
    });

    await this.prisma.activityLog.create({
      data: {
        action: `Deleted teacher ${teacher.user.fullName}`,
        actorName: 'Admin',
      },
    });

    return { ok: true };
  }

  async getTeacher(schoolId: string, id: string) {
    const teacher = await this.prisma.teacher.findUnique({
      where: { id },
      include: {
        user: true,
        classes: {
          where: { schoolId },
          orderBy: [{ grade: 'asc' }, { section: 'asc' }],
        },
      },
    });
    if (!teacher || teacher.user.schoolId !== schoolId) {
      throw new NotFoundException('Teacher not found');
    }

    return {
      id: teacher.id,
      fullName: teacher.user.fullName,
      email: teacher.user.email,
      phone: teacher.user.phone,
      employeeCode: teacher.employeeCode,
      department: teacher.department,
      subjects: teacher.subjects,
      gender: teacher.gender,
      avatarUrl: teacher.user.avatarUrl,
      status: 'ACTIVE',
      classes: teacher.classes.map((c) => ({
        id: c.id,
        name: c.name,
        grade: c.grade,
        section: c.section,
        category: c.category,
        room: c.room,
      })),
      createdAt: teacher.user.createdAt,
    };
  }

  /** Move classes saved under the wrong school (legacy create bug) into the admin's school. */
  private async reassignMisplacedClasses(targetSchoolId: string) {
    const ownCount = await this.prisma.class.count({
      where: { schoolId: targetSchoolId },
    });
    if (ownCount > 0) return;

    const misplaced = await this.prisma.class.findMany({
      where: { schoolId: { not: targetSchoolId } },
      select: { schoolId: true },
      take: 100,
    });
    if (misplaced.length === 0) return;

    const sourceSchoolIds = [...new Set(misplaced.map((c) => c.schoolId))];
    if (sourceSchoolIds.length !== 1) return;

    await this.prisma.class.updateMany({
      where: { schoolId: sourceSchoolIds[0] },
      data: { schoolId: targetSchoolId },
    });
  }

  async classStats(schoolId: string) {
    await this.reassignMisplacedClasses(schoolId);

    const schoolFilter = { schoolId };
    const [totalClasses, sections, students, newMonth] = await Promise.all([
      this.prisma.class.count({ where: schoolFilter }),
      this.prisma.class.count({ where: schoolFilter }),
      this.prisma.student.count({ where: { class: { schoolId } } }),
      this.prisma.class.count({
        where: {
          schoolId,
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

  async listClasses(schoolId: string, search?: string) {
    await this.reassignMisplacedClasses(schoolId);

    const where: Prisma.ClassWhereInput = { schoolId };
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
      streamGroup: c.streamGroup || null,
      name: c.name,
      category: c.category,
      room: c.room,
      studentCount: c._count.students,
      classTeacher: c.classTeacher
        ? {
            id: c.classTeacher.id,
            name: c.classTeacher.user.fullName,
            subject: c.classTeacher.subjects[0] ?? c.classTeacher.department,
            avatarUrl: c.classTeacher.user.avatarUrl,
          }
        : null,
    }));
  }

  async getClass(id: string) {
    const cls = await this.prisma.class.findUnique({
      where: { id },
      include: {
        school: true,
        classTeacher: { include: { user: true } },
        students: { orderBy: [{ rollNumber: 'asc' }, { fullName: 'asc' }] },
      },
    });
    if (!cls) throw new NotFoundException('Class not found');

    const boys = cls.students.filter((s) => s.gender === 'MALE').length;
    const girls = cls.students.filter((s) => s.gender === 'FEMALE').length;

    return {
      id: cls.id,
      grade: cls.grade,
      section: cls.section,
      name: cls.name,
      category: cls.category,
      room: cls.room,
      academicYear: cls.academicYear,
      schoolName: cls.school.name,
      studentCount: cls.students.length,
      boys,
      girls,
      classTeacher: cls.classTeacher
        ? {
            id: cls.classTeacher.id,
            name: cls.classTeacher.user.fullName,
            email: cls.classTeacher.user.email,
            phone: cls.classTeacher.user.phone,
            department: cls.classTeacher.department,
            subjects: cls.classTeacher.subjects,
            gender: cls.classTeacher.gender,
            avatarUrl: cls.classTeacher.user.avatarUrl,
          }
        : null,
      students: cls.students.map((s) => ({
        id: s.id,
        fullName: s.fullName,
        studentCode: s.studentCode,
        rollNumber: s.rollNumber,
        gender: s.gender,
        status: s.status,
        avatarUrl: s.avatarUrl,
      })),
    };
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

  async createTeacher(schoolId: string, dto: CreateTeacherDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({
      where: { schoolId_email: { schoolId, email } },
    });
    if (existing) throw new ConflictException('Email already registered');

    const count = await this.prisma.teacher.count();
    const employeeCode = `TCH${String(count + 1).padStart(4, '0')}`;
    const passwordHash = await bcrypt.hash(dto.password ?? 'Admin@123', 10);

    const user = await this.prisma.user.create({
      data: {
        schoolId,
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
        gender: dto.gender ?? 'MALE',
        department:
          dto.department?.trim() || dto.subjects[0]?.trim() || 'General',
        subjects: dto.subjects,
      },
    });

    if (dto.classTeacherClassId) {
      const cls = await this.prisma.class.findUnique({
        where: { id: dto.classTeacherClassId },
      });
      if (!cls || cls.schoolId !== schoolId) {
        throw new BadRequestException('Selected class not found');
      }
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

  async createClass(schoolId: string, dto: CreateClassDto) {
    let streamGroup = '';
    try {
      streamGroup = validateStreamGroupForGrade(dto.grade, dto.streamGroup);
    } catch (e) {
      const code = e instanceof Error ? e.message : '';
      if (code === 'GROUP_REQUIRED') {
        throw new BadRequestException(
          'Group name is required for 11th and 12th classes',
        );
      }
      if (code === 'GROUP_INVALID') {
        throw new BadRequestException('Invalid group name for senior class');
      }
      throw e;
    }

    const academicYear = dto.academicYear ?? '2025-26';
    const section = dto.section.toUpperCase();
    const existing = await this.prisma.class.findFirst({
      where: { schoolId, grade: dto.grade, section, streamGroup, academicYear },
    });
    if (existing) {
      throw new ConflictException(
        isSeniorGrade(dto.grade)
          ? 'Class with this grade, section and group already exists'
          : 'Class with this grade and section already exists',
      );
    }

    const defaultName = isSeniorGrade(dto.grade)
      ? `Class ${dto.grade}-${section} · ${streamGroup}`
      : `Class ${dto.grade}-${section}`;

    const category = isSeniorGrade(dto.grade)
      ? streamGroup
      : (dto.category?.trim() || 'General');

    let classTeacherId: string | undefined;
    if (dto.classTeacherId?.trim()) {
      const teacher = await this.prisma.teacher.findUnique({
        where: { id: dto.classTeacherId.trim() },
        include: { user: true },
      });
      if (!teacher || teacher.user.schoolId !== schoolId) {
        throw new BadRequestException(
          'Selected class teacher is invalid or no longer available',
        );
      }
      classTeacherId = teacher.id;
    }

    const cls = await this.prisma.class.create({
      data: {
        schoolId,
        grade: dto.grade,
        section,
        streamGroup,
        name: dto.name.trim() || defaultName,
        category,
        room: dto.room?.trim(),
        academicYear,
        classTeacherId,
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
      streamGroup: cls.streamGroup || null,
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

  async getProfile(schoolId: string, userId: string) {
    const [school, user] = await Promise.all([
      this.prisma.school.findUnique({
        where: { id: schoolId },
        select: {
          id: true,
          name: true,
          code: true,
          phone: true,
          address: true,
          city: true,
          logoUrl: true,
        },
      }),
      this.prisma.user.findFirst({
        where: { id: userId, schoolId },
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          role: true,
        },
      }),
    ]);

    if (!school || !user) {
      throw new NotFoundException('Profile not found');
    }

    return { school, user };
  }

  async updateProfile(
    schoolId: string,
    userId: string,
    dto: UpdateSchoolProfileDto,
  ) {
    const schoolData: {
      name?: string;
      phone?: string | null;
      address?: string | null;
      city?: string | null;
    } = {};

    if (dto.name !== undefined) schoolData.name = dto.name.trim();
    if (dto.phone !== undefined) schoolData.phone = dto.phone.trim() || null;
    if (dto.address !== undefined) schoolData.address = dto.address.trim() || null;
    if (dto.city !== undefined) schoolData.city = dto.city.trim() || null;

    const userData: { fullName?: string; phone?: string | null } = {};
    if (dto.fullName !== undefined) userData.fullName = dto.fullName.trim();
    if (dto.adminPhone !== undefined) {
      userData.phone = dto.adminPhone.trim() || null;
    }

    const [school, user] = await this.prisma.$transaction([
      this.prisma.school.update({
        where: { id: schoolId },
        data: schoolData,
        select: {
          id: true,
          name: true,
          code: true,
          phone: true,
          address: true,
          city: true,
          logoUrl: true,
        },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: userData,
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          role: true,
        },
      }),
    ]);

    return { school, user };
  }

  async listAnnouncements(schoolId: string) {
    return this.prisma.announcement.findMany({
      where: { schoolId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async createAnnouncement(
    schoolId: string,
    userId: string,
    _authorName: string,
    dto: CreateAnnouncementDto,
  ) {
    const author = await this.prisma.user.findFirst({
      where: { id: userId, schoolId },
      select: { fullName: true },
    });
    const postedBy = author?.fullName ?? 'Admin';

    const announcement = await this.prisma.announcement.create({
      data: {
        schoolId,
        authorId: userId,
        title: dto.title.trim(),
        body: dto.body.trim(),
        postedBy,
        audience: dto.audience,
        eventDate: dto.eventDate ? new Date(dto.eventDate) : null,
      },
    });

    const teachers = await this.prisma.user.findMany({
      where: { schoolId, role: UserRole.TEACHER },
      select: { id: true },
    });

    if (teachers.length > 0) {
      await this.prisma.appNotification.createMany({
        data: teachers.map((teacher) => ({
          userId: teacher.id,
          announcementId: announcement.id,
          title: `New announcement: ${announcement.title}`,
          body: announcement.body.slice(0, 200),
        })),
      });
    }

    await this.prisma.activityLog.create({
      data: {
        action: `Published announcement (${dto.audience === AnnouncementAudience.TEACHERS ? 'teachers' : 'teachers & parents'})`,
        actorName: postedBy,
      },
    });

    return announcement;
  }

  async reportsOverview() {
    const schoolId = await this.resolveSchoolId();
    const [students, teachers, classes, activities, feeChart] =
      await Promise.all([
        this.studentStats(),
        this.teacherStats(schoolId),
        this.classStats(schoolId),
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
