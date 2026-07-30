-- Adds the leave-request workflow, the library (books + issues), tenant-scopes
-- and enriches Event for the parent calendar, and gives AppNotification an
-- idempotency key so the daily automation job never double-sends.

-- CreateEnum
CREATE TYPE "LeaveStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- Event is now tenant-scoped with calendar metadata. Pre-existing rows were
-- global demo events with no school to attribute them to; drop them (matching
-- the ActivityLog precedent) rather than misassign a tenant. The table is
-- emptied first so the NOT NULL schoolId can be added without a backfill.
DELETE FROM "Event";
ALTER TABLE "Event" ADD COLUMN "schoolId" TEXT NOT NULL;
ALTER TABLE "Event" ADD COLUMN "description" TEXT;
ALTER TABLE "Event" ADD COLUMN "category" TEXT NOT NULL DEFAULT 'General';

ALTER TABLE "Event"
  ADD CONSTRAINT "Event_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "Event_schoolId_startAt_idx" ON "Event"("schoolId", "startAt");

-- AppNotification idempotency key. Nullable + unique: Postgres allows many
-- NULLs in a unique index, so one-off notifications (chat, leave) stay NULL
-- while automated reminders carry a dedupeKey that blocks a re-run's duplicate.
ALTER TABLE "AppNotification" ADD COLUMN "dedupeKey" TEXT;
CREATE UNIQUE INDEX "AppNotification_dedupeKey_key" ON "AppNotification"("dedupeKey");

-- CreateTable: LeaveRequest
CREATE TABLE "LeaveRequest" (
    "id" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "requestedByUserId" TEXT NOT NULL,
    "fromDate" DATE NOT NULL,
    "toDate" DATE NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "LeaveStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedByTeacherId" TEXT,
    "reviewNote" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeaveRequest_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "LeaveRequest_studentId_createdAt_idx"
  ON "LeaveRequest"("studentId", "createdAt");

ALTER TABLE "LeaveRequest"
  ADD CONSTRAINT "LeaveRequest_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LeaveRequest"
  ADD CONSTRAINT "LeaveRequest_requestedByUserId_fkey"
  FOREIGN KEY ("requestedByUserId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LeaveRequest"
  ADD CONSTRAINT "LeaveRequest_reviewedByTeacherId_fkey"
  FOREIGN KEY ("reviewedByTeacherId") REFERENCES "Teacher"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable: LibraryBook
CREATE TABLE "LibraryBook" (
    "id" TEXT NOT NULL,
    "schoolId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "author" TEXT,
    "isbn" TEXT,
    "category" TEXT NOT NULL DEFAULT 'General',
    "totalCopies" INTEGER NOT NULL DEFAULT 1,
    "availableCopies" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LibraryBook_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "LibraryBook_schoolId_idx" ON "LibraryBook"("schoolId");

ALTER TABLE "LibraryBook"
  ADD CONSTRAINT "LibraryBook_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable: BookIssue
CREATE TABLE "BookIssue" (
    "id" TEXT NOT NULL,
    "bookId" TEXT NOT NULL,
    "studentId" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "returnedAt" TIMESTAMP(3),

    CONSTRAINT "BookIssue_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "BookIssue_studentId_returnedAt_idx"
  ON "BookIssue"("studentId", "returnedAt");

ALTER TABLE "BookIssue"
  ADD CONSTRAINT "BookIssue_bookId_fkey"
  FOREIGN KEY ("bookId") REFERENCES "LibraryBook"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "BookIssue"
  ADD CONSTRAINT "BookIssue_studentId_fkey"
  FOREIGN KEY ("studentId") REFERENCES "Student"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
