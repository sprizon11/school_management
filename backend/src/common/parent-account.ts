import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { UserRole } from '@prisma/client';

/** Creates a parent login for a student when guardian details exist. */
export async function ensureParentAccount(
  prisma: PrismaService,
  schoolId: string,
  student: {
    id: string;
    studentCode: string;
    fullName: string;
    fatherName?: string | null;
    fatherPhone?: string | null;
    motherName?: string | null;
    motherPhone?: string | null;
  },
) {
  const existing = await prisma.parent.findUnique({
    where: { studentId: student.id },
  });
  if (existing) return existing;

  const guardianName =
    student.fatherName?.trim() ||
    student.motherName?.trim() ||
    `Parent of ${student.fullName}`;
  const guardianPhone =
    student.fatherPhone?.trim() || student.motherPhone?.trim() || null;

  const email = `parent.${student.studentCode.toLowerCase()}@school.parent`;
  const existingUser = await prisma.user.findFirst({
    where: { schoolId, email },
  });
  if (existingUser) {
    return prisma.parent.create({
      data: { userId: existingUser.id, studentId: student.id },
    });
  }

  const passwordHash = await bcrypt.hash('Parent@123', 10);
  const user = await prisma.user.create({
    data: {
      schoolId,
      email,
      passwordHash,
      role: UserRole.PARENT,
      fullName: guardianName,
      phone: guardianPhone,
    },
  });

  return prisma.parent.create({
    data: { userId: user.id, studentId: student.id },
  });
}
