import { PrismaClient } from '@prisma/client';
import { wipeAllClassesAndTeachers } from '../src/common/wipe-classes-and-teachers';

const prisma = new PrismaClient();

async function main() {
  console.log('Removing ALL classes, teachers, and their students...');
  const result = await wipeAllClassesAndTeachers(prisma);
  console.log(`Students removed: ${result.studentsRemoved}`);
  console.log(`Homework removed: ${result.homeworkRemoved}`);
  console.log(`Classes removed: ${result.classesRemoved}`);
  console.log(`Teachers removed: ${result.teachersRemoved}`);
  console.log('Done. Admin accounts were kept.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
