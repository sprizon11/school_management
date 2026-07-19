-- Teacher.employeeCode was globally unique but generated per school, so the
-- first teacher at every school after the first collided on "TCH0001".
-- Scope the code (and the teacher itself) to a school.

ALTER TABLE "Teacher" ADD COLUMN "schoolId" TEXT;

UPDATE "Teacher" t
SET "schoolId" = u."schoolId"
FROM "User" u
WHERE u."id" = t."userId";

ALTER TABLE "Teacher" ALTER COLUMN "schoolId" SET NOT NULL;

DROP INDEX IF EXISTS "Teacher_employeeCode_key";

ALTER TABLE "Teacher"
  ADD CONSTRAINT "Teacher_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Existing per-school codes may already collide across the global namespace;
-- renumber duplicates within each school before enforcing the constraint.
WITH renumbered AS (
  SELECT
    "id",
    'TCH' || LPAD(
      ROW_NUMBER() OVER (PARTITION BY "schoolId" ORDER BY "employeeCode", "id")::TEXT,
      4, '0'
    ) AS new_code
  FROM "Teacher"
  WHERE "schoolId" IN (
    SELECT "schoolId" FROM "Teacher"
    GROUP BY "schoolId", "employeeCode"
    HAVING COUNT(*) > 1
  )
)
UPDATE "Teacher" t
SET "employeeCode" = r.new_code
FROM renumbered r
WHERE t."id" = r."id";

CREATE UNIQUE INDEX "Teacher_schoolId_employeeCode_key"
  ON "Teacher"("schoolId", "employeeCode");

-- ActivityLog had no tenant column, so every school's admin dashboard and
-- reports page read the whole platform's activity feed.
ALTER TABLE "ActivityLog" ADD COLUMN "schoolId" TEXT;

-- Pre-existing rows can't be attributed to a school after the fact; they were
-- only ever surfaced as a recent-activity feed, so drop them rather than
-- misattribute them to an arbitrary tenant.
DELETE FROM "ActivityLog";

ALTER TABLE "ActivityLog" ALTER COLUMN "schoolId" SET NOT NULL;

ALTER TABLE "ActivityLog"
  ADD CONSTRAINT "ActivityLog_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "ActivityLog_schoolId_createdAt_idx"
  ON "ActivityLog"("schoolId", "createdAt");
