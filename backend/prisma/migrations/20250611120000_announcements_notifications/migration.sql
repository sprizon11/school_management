-- School phone
ALTER TABLE "School" ADD COLUMN IF NOT EXISTS "phone" TEXT;

-- Announcement audience enum
DO $$ BEGIN
  CREATE TYPE "AnnouncementAudience" AS ENUM ('TEACHERS', 'TEACHERS_AND_PARENTS');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Announcement school scope
ALTER TABLE "Announcement" ADD COLUMN IF NOT EXISTS "schoolId" TEXT;
ALTER TABLE "Announcement" ADD COLUMN IF NOT EXISTS "authorId" TEXT;
ALTER TABLE "Announcement" ADD COLUMN IF NOT EXISTS "audience" "AnnouncementAudience" NOT NULL DEFAULT 'TEACHERS';

UPDATE "Announcement"
SET "schoolId" = (SELECT "id" FROM "School" ORDER BY "createdAt" ASC LIMIT 1)
WHERE "schoolId" IS NULL;

ALTER TABLE "Announcement" ALTER COLUMN "schoolId" SET NOT NULL;

ALTER TABLE "Announcement" DROP CONSTRAINT IF EXISTS "Announcement_schoolId_fkey";
ALTER TABLE "Announcement"
  ADD CONSTRAINT "Announcement_schoolId_fkey"
  FOREIGN KEY ("schoolId") REFERENCES "School"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- In-app notifications
CREATE TABLE IF NOT EXISTS "AppNotification" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "announcementId" TEXT,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "readAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AppNotification_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "AppNotification_userId_readAt_idx" ON "AppNotification"("userId", "readAt");

ALTER TABLE "AppNotification" DROP CONSTRAINT IF EXISTS "AppNotification_userId_fkey";
ALTER TABLE "AppNotification"
  ADD CONSTRAINT "AppNotification_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AppNotification" DROP CONSTRAINT IF EXISTS "AppNotification_announcementId_fkey";
ALTER TABLE "AppNotification"
  ADD CONSTRAINT "AppNotification_announcementId_fkey"
  FOREIGN KEY ("announcementId") REFERENCES "Announcement"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
