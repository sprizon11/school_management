import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

function isSeedStudentCode(code: string): boolean {
  if (code === 'ARU24001') return true;
  return /^STU\d{5}$/.test(code);
}

function isSeedTeacherEmail(email: string): boolean {
  return (
    email.endsWith('@seed.demo') ||
    email === 'teacher@school.demo' ||
    email === 'priya@school.demo'
  );
}

function isSeedTeacherCode(code: string): boolean {
  return /^TCH24\d{3}$/.test(code);
}

function isSeedParentEmail(email: string): boolean {
  return email === 'parent@school.demo' || /^parent\d+@seed\.demo$/.test(email);
}

async function main() {
  console.log('Removing demo students, teachers, and related data...');

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

  const keptStudents = allStudents.filter((s) => !demoStudentIds.includes(s.id));
  console.log(`Students to remove: ${demoStudentIds.length}`);
  console.log(`Students to keep: ${keptStudents.length}`);
  keptStudents.forEach((s) =>
    console.log(`  keep: ${s.fullName} (${s.studentCode})`),
  );

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

    await prisma.parentStudent.deleteMany({
      where: { studentId: { in: demoStudentIds } },
    });
    await prisma.student.deleteMany({
      where: { id: { in: demoStudentIds } },
    });
  }

  const allTeachers = await prisma.teacher.findMany({
    include: { user: { select: { email: true } } },
  });

  const demoTeacherIds = allTeachers
    .filter(
      (t) =>
        isSeedTeacherEmail(t.user.email) || isSeedTeacherCode(t.employeeCode),
    )
    .map((t) => t.id);

  const keptTeachers = allTeachers.filter((t) => !demoTeacherIds.includes(t.id));
  console.log(`Teachers to remove: ${demoTeacherIds.length}`);
  console.log(`Teachers to keep: ${keptTeachers.length}`);
  keptTeachers.forEach((t) =>
    console.log(`  keep: ${t.user.email} (${t.employeeCode})`),
  );

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
  }

  const demoParents = await prisma.parent.findMany({
    include: { user: { select: { email: true } } },
  });

  const demoParentIds = demoParents
    .filter((p) => isSeedParentEmail(p.user.email))
    .map((p) => p.id);

  if (demoParentIds.length > 0) {
    await prisma.parentStudent.deleteMany({
      where: { parentId: { in: demoParentIds } },
    });
    await prisma.parent.deleteMany({
      where: { id: { in: demoParentIds } },
    });
    console.log(`Parents removed: ${demoParentIds.length}`);
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
  console.log('Admin login (kept): admin@school.demo / Admin@123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
