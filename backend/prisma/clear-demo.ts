import { PrismaClient, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

function isSeedStudentCode(code: string) {
  if (code === 'ARU24001') return true;
  return /^STU\d{5}$/.test(code);
}

function isSeedTeacherEmail(email: string) {
  return (
    email.endsWith('@seed.demo') ||
    email === 'teacher@school.demo' ||
    email === 'priya@school.demo'
  );
}

function isSeedTeacherCode(code: string) {
  return /^TCH24\d{3}$/.test(code);
}

function isDemoAdminEmail(email: string) {
  return email === 'admin2@school.demo' || email.endsWith('@seed.demo');
}

async function main() {
  console.log('Removing all demo data...');

  const allStudents = await prisma.student.findMany({
    select: { id: true, studentCode: true, email: true, fullName: true },
  });

  const demoStudentIds = allStudents
    .filter(
      (s) =>
        isSeedStudentCode(s.studentCode) ||
        (s.email?.includes('@seed.demo') ?? false) ||
        (s.email?.includes('@student.demo') ?? false),
    )
    .map((s) => s.id);

  if (demoStudentIds.length > 0) {
    const assignments = await prisma.feeAssignment.findMany({
      where: { studentId: { in: demoStudentIds } },
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
      where: { id: { in: demoStudentIds } },
    });
  }

  console.log(`Students removed: ${demoStudentIds.length}`);

  const allTeachers = await prisma.teacher.findMany({
    include: { user: { select: { id: true, email: true } } },
  });

  const demoTeachers = allTeachers.filter(
    (t) =>
      isSeedTeacherEmail(t.user.email) || isSeedTeacherCode(t.employeeCode),
  );
  const demoTeacherIds = demoTeachers.map((t) => t.id);
  const demoTeacherUserIds = demoTeachers.map((t) => t.user.id);

  if (demoTeacherIds.length > 0) {
    await prisma.homework.deleteMany({
      where: { teacherId: { in: demoTeacherIds } },
    });
    await prisma.mark.updateMany({
      where: { teacherId: { in: demoTeacherIds } },
      data: { teacherId: null },
    });
    await prisma.class.updateMany({
      where: { classTeacherId: { in: demoTeacherIds } },
      data: { classTeacherId: null },
    });
    await prisma.teacher.deleteMany({
      where: { id: { in: demoTeacherIds } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: demoTeacherUserIds } },
    });
  }

  console.log(`Teachers removed: ${demoTeacherIds.length}`);

  const demoAdmins = await prisma.user.findMany({
    where: { role: UserRole.ADMIN },
    select: { id: true, email: true },
  });
  const demoAdminIds = demoAdmins
    .filter((u) => isDemoAdminEmail(u.email))
    .map((u) => u.id);

  if (demoAdminIds.length > 0) {
    await prisma.user.deleteMany({
      where: { id: { in: demoAdminIds } },
    });
  }

  console.log(`Demo admins removed: ${demoAdminIds.length}`);

  const remainingStudents = await prisma.student.count();
  if (remainingStudents === 0) {
    await prisma.homework.deleteMany();
    await prisma.class.updateMany({ data: { classTeacherId: null } });
    const classesRemoved = await prisma.class.deleteMany();
    console.log(`Classes removed: ${classesRemoved.count}`);
  }

  const orphanFeeStructures = await prisma.feeStructure.findMany({
    where: { assignments: { none: {} } },
  });
  if (orphanFeeStructures.length > 0) {
    await prisma.feeStructure.deleteMany({
      where: { id: { in: orphanFeeStructures.map((f) => f.id) } },
    });
  }

  await prisma.announcement.deleteMany();
  await prisma.event.deleteMany();
  await prisma.activityLog.deleteMany();

  console.log('Demo cleanup completed.');
  console.log('Kept admin login: admin@school.demo / Admin@123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
