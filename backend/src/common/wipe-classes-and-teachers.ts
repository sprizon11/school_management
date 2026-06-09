import { PrismaClient, UserRole } from '@prisma/client';

async function deleteAllStudents(prisma: PrismaClient) {
  const students = await prisma.student.findMany({ select: { id: true } });
  const studentIds = students.map((s) => s.id);
  if (studentIds.length === 0) return 0;

  const assignments = await prisma.feeAssignment.findMany({
    where: { studentId: { in: studentIds } },
    select: { id: true },
  });
  const assignmentIds = assignments.map((a) => a.id);

  if (assignmentIds.length > 0) {
    const installments = await prisma.feeInstallment.findMany({
      where: { assignmentId: { in: assignmentIds } },
      select: { id: true },
    });
    const installmentIds = installments.map((i) => i.id);

    if (installmentIds.length > 0) {
      await prisma.feePayment.deleteMany({
        where: { installmentId: { in: installmentIds } },
      });
    }
    await prisma.feeInstallment.deleteMany({
      where: { assignmentId: { in: assignmentIds } },
    });
    await prisma.feeAssignment.deleteMany({
      where: { id: { in: assignmentIds } },
    });
  }

  await prisma.student.deleteMany({
    where: { id: { in: studentIds } },
  });

  return studentIds.length;
}

export async function wipeAllClassesAndTeachers(prisma: PrismaClient) {
  const studentsRemoved = await deleteAllStudents(prisma);

  const teacherProfiles = await prisma.teacher.findMany({ select: { id: true } });
  const teacherIds = teacherProfiles.map((t) => t.id);

  if (teacherIds.length > 0) {
    await prisma.mark.updateMany({
      where: { teacherId: { in: teacherIds } },
      data: { teacherId: null },
    });
    await prisma.class.updateMany({
      where: { classTeacherId: { in: teacherIds } },
      data: { classTeacherId: null },
    });
  }

  const homeworkRemoved = await prisma.homework.deleteMany();
  await prisma.class.updateMany({ data: { classTeacherId: null } });
  const classesRemoved = await prisma.class.deleteMany();

  const teachersRemoved = await prisma.user.deleteMany({
    where: { role: UserRole.TEACHER },
  });

  return {
    studentsRemoved,
    homeworkRemoved: homeworkRemoved.count,
    classesRemoved: classesRemoved.count,
    teachersRemoved: teachersRemoved.count,
  };
}
