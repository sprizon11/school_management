import {
  AttendanceStatus,
  FeeInstallmentStatus,
  FeeStructureType,
  Gender,
  PrismaClient,
  StudentStatus,
  UserRole,
} from '@prisma/client';
import { faker } from '@faker-js/faker';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();
faker.seed(2024);

const STUDENT_COUNT = Math.min(
  300,
  Math.max(200, parseInt(process.env.SEED_STUDENT_COUNT || '250', 10)),
);

const SUBJECTS = [
  'Science',
  'Mathematics',
  'English',
  'Social Science',
  'Computer',
  'Hindi',
];

const SECTIONS = ['A', 'B', 'C', 'D'];
const GRADES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

function gradeCategory(grade: number) {
  if (grade <= 5) return 'Primary';
  if (grade <= 10) return 'Secondary';
  return 'Senior Secondary';
}

async function hashPassword(password: string) {
  return bcrypt.hash(password, 10);
}

async function seedMinimal() {
  console.log('Minimal seed (admin + school + subjects only)...');

  const passwordHash = await hashPassword('Admin@123');

  const school = await prisma.school.upsert({
    where: { code: 'greenfield' },
    create: {
      name: 'Greenfield Public School',
      code: 'greenfield',
      address: 'Chennai, Tamil Nadu',
      city: 'Chennai',
      isActive: true,
    },
    update: { isActive: true },
  });

  await prisma.user.upsert({
    where: {
      schoolId_email: { schoolId: school.id, email: 'admin@school.demo' },
    },
    create: {
      schoolId: school.id,
      email: 'admin@school.demo',
      passwordHash,
      role: UserRole.ADMIN,
      fullName: 'Super Administrator',
      phone: '+919876543210',
    },
    update: {},
  });

  for (const name of SUBJECTS) {
    await prisma.subject.upsert({
      where: { name },
      create: { name },
      update: {},
    });
  }

  console.log('Minimal seed done. Login: admin@school.demo / Admin@123');
  console.log('Add students and teachers from the app — no demo data inserted.');
}

async function seedFullDemo() {
  console.log('Full demo seed (250 students, 70 teachers)...');
  await prisma.feePayment.deleteMany();
  await prisma.feeInstallment.deleteMany();
  await prisma.feeAssignment.deleteMany();
  await prisma.feeStructure.deleteMany();
  await prisma.mark.deleteMany();
  await prisma.attendanceRecord.deleteMany();
  await prisma.homework.deleteMany();
  await prisma.student.deleteMany();
  await prisma.class.deleteMany();
  await prisma.teacher.deleteMany();
  await prisma.user.deleteMany();
  await prisma.announcement.deleteMany();
  await prisma.event.deleteMany();
  await prisma.activityLog.deleteMany();
  await prisma.subject.deleteMany();
  await prisma.school.deleteMany();

  const school = await prisma.school.create({
    data: {
      name: 'Greenfield Public School',
      code: 'greenfield',
      address: 'Chennai, Tamil Nadu',
      city: 'Chennai',
      isActive: true,
    },
  });

  const subjectRecords = await Promise.all(
    SUBJECTS.map((name) => prisma.subject.create({ data: { name } })),
  );

  const passwordHash = await hashPassword('Admin@123');
  const demoHash = await hashPassword('Demo@123');

  await prisma.user.create({
    data: {
      schoolId: school.id,
      email: 'admin@school.demo',
      passwordHash,
      role: UserRole.ADMIN,
      fullName: 'Super Administrator',
      phone: '+919876543210',
    },
  });

  await prisma.user.create({
    data: {
      schoolId: school.id,
      email: 'admin2@school.demo',
      passwordHash: demoHash,
      role: UserRole.ADMIN,
      fullName: 'Assistant Admin',
    },
  });

  const classes: { id: string; grade: number; section: string; name: string }[] =
    [];
  const academicYear = '2024-2025';

  for (const grade of GRADES) {
    const sectionCount = grade >= 9 ? 4 : 3;
    for (let i = 0; i < sectionCount; i++) {
      const section = SECTIONS[i];
      const name = `Class ${grade}`;
      const cls = await prisma.class.create({
        data: {
          schoolId: school.id,
          grade,
          section,
          name,
          category: gradeCategory(grade),
          room: `Room ${200 + grade}`,
          academicYear,
        },
      });
      classes.push({
        id: cls.id,
        grade,
        section,
        name: `${grade}${section}`,
      });
    }
  }

  console.log(`Created ${classes.length} classes`);

  const teachers: { id: string; userId: string }[] = [];
  const teacherTarget = 70;

  for (let t = 0; t < teacherTarget; t++) {
    const firstName = faker.person.firstName();
    const lastName = faker.person.lastName();
    const fullName = `${firstName} ${lastName}`;
    const email =
      t === 0
        ? 'teacher@school.demo'
        : t === 1
          ? 'priya@school.demo'
          : `teacher${String(t + 1).padStart(3, '0')}@seed.demo`;

    const user = await prisma.user.create({
      data: {
        schoolId: school.id,
        email,
        passwordHash: t < 2 ? passwordHash : demoHash,
        role: UserRole.TEACHER,
        fullName: t === 0 ? 'Ravi Kumar' : t === 1 ? 'Ms. Priya Sharma' : fullName,
        phone: faker.phone.number({ style: 'international' }),
      },
    });

    const teacher = await prisma.teacher.create({
      data: {
        userId: user.id,
        employeeCode: `TCH24${String(t + 1).padStart(3, '0')}`,
        department:
          t === 0 ? 'Mathematics' : t === 1 ? 'Science' : faker.helpers.arrayElement(SUBJECTS),
        subjects: [
          t === 0 ? 'Mathematics' : t === 1 ? 'Science' : faker.helpers.arrayElement(SUBJECTS),
        ],
      },
    });
    teachers.push({ id: teacher.id, userId: user.id });
  }

  for (let i = 0; i < classes.length; i++) {
    const teacher = teachers[i % teachers.length];
    await prisma.class.update({
      where: { id: classes[i].id },
      data: { classTeacherId: teacher.id },
    });
  }

  const class9A = classes.find((c) => c.grade === 9 && c.section === 'A');
  if (class9A) {
    const ravi = teachers[0];
    await prisma.class.update({
      where: { id: class9A.id },
      data: { classTeacherId: ravi.id },
    });
  }

  console.log(`Created ${teachers.length} teachers`);

  const studentsPerClass = Math.ceil(STUDENT_COUNT / classes.length);
  let studentIndex = 0;
  const allStudents: { id: string; classId: string }[] = [];

  for (const cls of classes) {
    const count =
      cls.grade === 9 && cls.section === 'A'
        ? 40
        : Math.min(studentsPerClass, STUDENT_COUNT - studentIndex);
    if (studentIndex >= STUDENT_COUNT) break;

    for (let s = 0; s < count && studentIndex < STUDENT_COUNT; s++) {
      studentIndex++;
      const gender =
        faker.number.float() > 0.45 ? Gender.MALE : Gender.FEMALE;
      const isAryan = class9A && cls.id === class9A.id && s === 14;

      const student = await prisma.student.create({
        data: {
          studentCode: isAryan
            ? 'ARU24001'
            : `STU${String(studentIndex).padStart(5, '0')}`,
          fullName: isAryan ? 'Aryan Kumar' : faker.person.fullName(),
          email: isAryan
            ? 'aryan.kumar@student.demo'
            : `student${studentIndex}@seed.demo`,
          gender,
          rollNumber: s + 1,
          dateOfBirth: faker.date.birthdate({ min: 6, max: 18, mode: 'age' }),
          status:
            faker.number.float() < 0.05
              ? StudentStatus.INACTIVE
              : StudentStatus.ACTIVE,
          classId: cls.id,
        },
      });
      allStudents.push({ id: student.id, classId: cls.id });
    }
  }

  console.log(`Created ${allStudents.length} students`);

  const feeStructure = await prisma.feeStructure.create({
    data: {
      type: FeeStructureType.TERM,
      termLabel: 'Apr-Jun 2024',
      academicYear,
      totalAmount: 36000,
    },
  });

  const termLabel = 'Apr-Jun 2024';
  const today = new Date();

  for (const st of allStudents) {
    const assignment = await prisma.feeAssignment.create({
      data: {
        studentId: st.id,
        feeStructureId: feeStructure.id,
        feeCode:
          st.id === aryan?.id
            ? 'FEE123456'
            : `FEE${faker.string.alphanumeric(6).toUpperCase()}`,
      },
    });

    const installments = [
      { label: '1st Installment', amount: 9000, status: FeeInstallmentStatus.PAID, due: new Date('2024-04-12') },
      { label: '2nd Installment', amount: 9000, status: FeeInstallmentStatus.PAID, due: new Date('2024-05-14') },
      { label: '3rd Installment', amount: 9000, status: FeeInstallmentStatus.PENDING, due: new Date('2024-06-15') },
      { label: '4th Installment', amount: 9000, status: FeeInstallmentStatus.UPCOMING, due: new Date('2024-07-15') },
    ];

    for (const inst of installments) {
      const installment = await prisma.feeInstallment.create({
        data: {
          assignmentId: assignment.id,
          label: inst.label,
          amount: inst.amount,
          dueDate: inst.due,
          status: inst.status,
        },
      });
      if (inst.status === FeeInstallmentStatus.PAID) {
        await prisma.feePayment.create({
          data: {
            installmentId: installment.id,
            amount: inst.amount,
            transactionId: `TXN${faker.string.numeric(10)}`,
            paidAt: inst.due,
            method: 'Online Payment',
          },
        });
      }
    }
  }

  for (let d = 90; d >= 0; d--) {
    const date = new Date(today);
    date.setDate(date.getDate() - d);
    if (date.getDay() === 0) continue;

    const batch = allStudents.slice(0, 50);
    for (const st of batch) {
      const r = faker.number.float();
      const status: AttendanceStatus =
        r < 0.92 ? AttendanceStatus.PRESENT : r < 0.96 ? AttendanceStatus.ABSENT : AttendanceStatus.LEAVE;
      await prisma.attendanceRecord.create({
        data: { studentId: st.id, date, status },
      });
    }
  }

  for (const st of allStudents) {
    for (const sub of subjectRecords) {
      const marks = 65 + Math.floor(faker.number.float() * 35);
      const grade =
        marks >= 90 ? 'A+' : marks >= 80 ? 'A' : marks >= 70 ? 'B+' : 'B';
      await prisma.mark.create({
        data: {
          studentId: st.id,
          subjectId: sub.id,
          termLabel,
          maxMarks: 100,
          marks,
          grade,
          teacherId: teachers[0].id,
        },
      });
    }
  }

  if (class9A) {
    const clsId = class9A.id;
    for (let h = 0; h < 8; h++) {
      await prisma.homework.create({
        data: {
          classId: clsId,
          teacherId: teachers[0].id,
          title: faker.lorem.sentence(4),
          description: faker.lorem.paragraph(),
          dueDate: faker.date.soon({ days: 14 }),
        },
      });
    }
  }

  const announcements = [
    {
      title: 'School Annual Day',
      body: 'Annual day celebration on 30th May 2024.',
      postedBy: 'Admin',
      eventDate: new Date('2024-05-30'),
    },
    {
      title: 'Holiday Notice',
      body: 'School will remain closed on 27th May 2024 on account of Holiday.',
      postedBy: 'Admin',
    },
    {
      title: 'Summer Vacation',
      body: 'Summer vacation from 15 May to 30 June 2024.',
      postedBy: 'Admin',
      eventDate: new Date('2024-06-15'),
    },
  ];

  for (const a of announcements) {
    await prisma.announcement.create({ data: a });
  }

  await prisma.event.createMany({
    data: [
      {
        title: 'Teacher Meeting',
        startAt: new Date('2024-05-24T10:00:00'),
        endAt: new Date('2024-05-24T11:00:00'),
        location: 'School Auditorium',
        color: '#635BFF',
      },
      {
        title: 'Unit Test - 1',
        startAt: new Date('2024-05-28T09:00:00'),
        location: 'Classrooms',
        color: '#22C55E',
      },
      {
        title: 'Annual Day Celebration',
        startAt: new Date('2024-05-30T14:00:00'),
        location: 'Main Ground',
        color: '#F97316',
      },
    ],
  });

  await prisma.activityLog.createMany({
    data: [
      { action: 'Added new student', actorName: 'Admin' },
      { action: 'Fee payment recorded', actorName: 'Admin' },
      { action: 'Published announcement', actorName: 'Admin' },
      { action: 'Updated class timetable', actorName: 'Admin' },
    ],
  });

  console.log('Seed completed successfully.');
  console.log(`Students: ${allStudents.length}`);
  console.log(`Classes: ${classes.length}`);
  console.log(`Teachers: ${teachers.length}`);
  console.log('Demo logins: admin@school.demo / teacher@school.demo (Admin@123)');
}

async function main() {
  if (process.env.SEED_DEMO_DATA === 'true') {
    await seedFullDemo();
  } else {
    await seedMinimal();
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
