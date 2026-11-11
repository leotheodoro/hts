ALTER TYPE "public"."exercise_unit" ADD VALUE 'calories';--> statement-breakpoint
ALTER TABLE "workout_template" ADD COLUMN "is_test" boolean DEFAULT false NOT NULL;