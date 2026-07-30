import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { UserRole } from '@prisma/client';
import { generateTempPassword } from '../auth/password.util';

/**
 * Creates a parent login for a student when guardian details exist.
 *
 * Returns the one-time temporary password when a *new* account is created so
 * the caller can surface it to the admin to hand over; `tempPassword` is null
 * when an account already existed (nothing new to reveal).
 */
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
  if (existing) return { parent: existing, tempPassword: null as string | null };

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
    const parent = await prisma.parent.create({
      data: { userId: existingUser.id, studentId: student.id },
    });
    return { parent, tempPassword: null as string | null };
  }

  const tempPassword = generateTempPassword();
  const passwordHash = await bcrypt.hash(tempPassword, 10);
  const user = await prisma.user.create({
    data: {
      schoolId,
      email,
      passwordHash,
      role: UserRole.PARENT,
      fullName: guardianName,
      phone: guardianPhone,
      mustChangePassword: true,
    },
  });

  const parent = await prisma.parent.create({
    data: { userId: user.id, studentId: student.id },
  });
  return { parent, tempPassword: tempPassword as string | null };
}
