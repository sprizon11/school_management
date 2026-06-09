-- Remove all parent accounts and parent portal data
DELETE FROM "ParentStudent";
DELETE FROM "Parent";
DELETE FROM "User" WHERE role = 'PARENT';

DROP TABLE IF EXISTS "ParentStudent";
DROP TABLE IF EXISTS "Parent";

ALTER TYPE "UserRole" RENAME TO "UserRole_old";
CREATE TYPE "UserRole" AS ENUM ('ADMIN', 'TEACHER');
ALTER TABLE "User" ALTER COLUMN "role" TYPE "UserRole" USING ("role"::text::"UserRole");
DROP TYPE "UserRole_old";
