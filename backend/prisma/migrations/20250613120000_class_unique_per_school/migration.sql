-- Class uniqueness must be per school (not global across tenants)
DROP INDEX IF EXISTS "Class_grade_section_streamGroup_academicYear_key";
DROP INDEX IF EXISTS "Class_grade_section_academicYear_key";

CREATE UNIQUE INDEX IF NOT EXISTS "Class_schoolId_grade_section_streamGroup_academicYear_key"
  ON "Class"("schoolId", "grade", "section", "streamGroup", "academicYear");
