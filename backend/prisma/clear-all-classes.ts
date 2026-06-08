import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function deleteAllStudents() {
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

  await prisma.parentStudent.deleteMany({
    where: { studentId: { in: studentIds } },
  });
  await prisma.student.deleteMany({
    where: { id: { in: studentIds } },
  });

  return studentIds.length;
}

async function main() {
  const classCount = await prisma.class.count();
  const studentCountBefore = await prisma.student.count();

  console.log(`Classes to remove: ${classCount}`);
  console.log(`Students to remove (required before classes): ${studentCountBefore}`);

  const studentsRemoved = await deleteAllStudents();
  const homeworkRemoved = await prisma.homework.deleteMany();
  await prisma.class.updateMany({ data: { classTeacherId: null } });
  const classesRemoved = await prisma.class.deleteMany();

  console.log(`Removed ${studentsRemoved} students`);
  console.log(`Removed ${homeworkRemoved.count} homework items`);
  console.log(`Removed ${classesRemoved.count} classes`);
  console.log('Teachers and admin accounts were kept.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
