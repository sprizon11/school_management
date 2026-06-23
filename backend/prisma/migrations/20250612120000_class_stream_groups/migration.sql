-- Stream/group for 11th & 12th classes (Accounts, Computer Science, etc.)
ALTER TABLE "Class" ADD COLUMN IF NOT EXISTS "streamGroup" TEXT NOT NULL DEFAULT '';

ALTER TABLE "Class" DROP CONSTRAINT IF EXISTS "Class_grade_section_academicYear_key";

CREATE UNIQUE INDEX IF NOT EXISTS "Class_grade_section_streamGroup_academicYear_key"
  ON "Class"("grade", "section", "streamGroup", "academicYear");
