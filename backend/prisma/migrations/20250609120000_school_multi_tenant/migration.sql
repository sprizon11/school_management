-- School registry fields
ALTER TABLE "School" ADD COLUMN IF NOT EXISTS "code" TEXT;
ALTER TABLE "School" ADD COLUMN IF NOT EXISTS "city" TEXT;
ALTER TABLE "School" ADD COLUMN IF NOT EXISTS "logoUrl" TEXT;
ALTER TABLE "School" ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT true;

UPDATE "School"
SET "code" = 'school-' || SUBSTRING("id", 1, 8)
WHERE "code" IS NULL;

UPDATE "School"
SET
  "code" = 'greenfield',
  "city" = 'Chennai',
  "isActive" = true
WHERE "name" = 'Greenfield Public School';

ALTER TABLE "School" ALTER COLUMN "code" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "School_code_key" ON "School"("code");

-- Link users to a school
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "schoolId" TEXT;

UPDATE "User"
SET "schoolId" = (SELECT "id" FROM "School" ORDER BY "createdAt" ASC LIMIT 1)
WHERE "schoolId" IS NULL;

INSERT INTO "School" ("id", "name", "code", "address", "isActive", "createdAt")
SELECT 'clschooldefault000000001', 'Default School', 'default-school', NULL, true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM "School");

UPDATE "User"
SET "schoolId" = (SELECT "id" FROM "School" ORDER BY "createdAt" ASC LIMIT 1)
WHERE "schoolId" IS NULL;

ALTER TABLE "User" ALTER COLUMN "schoolId" SET NOT NULL;

ALTER TABLE "User" DROP CONSTRAINT IF EXISTS "User_email_key";
DROP INDEX IF EXISTS "User_email_key";

CREATE UNIQUE INDEX IF NOT EXISTS "User_schoolId_email_key" ON "User"("schoolId", "email");

ALTER TABLE "User" DROP CONSTRAINT IF EXISTS "User_schoolId_fkey";
ALTER TABLE "User"
  ADD CONSTRAINT "User_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
