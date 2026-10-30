-- The account keeps the object key of its photo in the private bucket; links are signed per response (#142).
ALTER TABLE "account" RENAME COLUMN "avatar_url" TO "avatar_key";
