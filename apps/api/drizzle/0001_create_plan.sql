CREATE TYPE "public"."arc_kind" AS ENUM('normal', 'special', 'filler');--> statement-breakpoint
CREATE TYPE "public"."arc_status" AS ENUM('queued', 'current', 'completed');--> statement-breakpoint
CREATE TYPE "public"."attribute" AS ENUM('strength', 'power', 'conditioning', 'core', 'mobility');--> statement-breakpoint
CREATE TYPE "public"."block_kind" AS ENUM('activation', 'strength', 'combo', 'chained_combo', 'fight_round', 'conditioning', 'core', 'mobility', 'cardio');--> statement-breakpoint
CREATE TYPE "public"."exercise_unit" AS ENUM('reps', 'seconds', 'meters', 'minutes');--> statement-breakpoint
CREATE TABLE "arc" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"saga_id" uuid NOT NULL,
	"name" text NOT NULL,
	"kanji" text,
	"program" text,
	"kind" "arc_kind" DEFAULT 'normal' NOT NULL,
	"weeks" smallint,
	"start_date" date,
	"status" "arc_status" DEFAULT 'queued' NOT NULL,
	"position" integer NOT NULL,
	"count_reset_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "block" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"workout_template_id" uuid NOT NULL,
	"kind" "block_kind" NOT NULL,
	"attributes" jsonb NOT NULL,
	"duration_minutes" smallint,
	"position" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "exercise" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"name" text NOT NULL,
	"normalized_name" text NOT NULL,
	"default_attribute" "attribute",
	"unit" "exercise_unit" DEFAULT 'reps' NOT NULL,
	"per_side" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "prescribed_exercise" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"block_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"sets_min" smallint NOT NULL,
	"sets_max" smallint NOT NULL,
	"targets" jsonb NOT NULL,
	"rest_seconds" integer,
	"position" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "saga" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"year" smallint NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "workout_template" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"arc_id" uuid NOT NULL,
	"source_template_id" uuid,
	"letter" text NOT NULL,
	"name" text NOT NULL,
	"focus" text,
	"position" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "arc" ADD CONSTRAINT "arc_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "arc" ADD CONSTRAINT "arc_saga_id_saga_id_fk" FOREIGN KEY ("saga_id") REFERENCES "public"."saga"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "block" ADD CONSTRAINT "block_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "block" ADD CONSTRAINT "block_workout_template_id_workout_template_id_fk" FOREIGN KEY ("workout_template_id") REFERENCES "public"."workout_template"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exercise" ADD CONSTRAINT "exercise_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercise" ADD CONSTRAINT "prescribed_exercise_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercise" ADD CONSTRAINT "prescribed_exercise_block_id_block_id_fk" FOREIGN KEY ("block_id") REFERENCES "public"."block"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "prescribed_exercise" ADD CONSTRAINT "prescribed_exercise_exercise_id_exercise_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercise"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "saga" ADD CONSTRAINT "saga_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_template" ADD CONSTRAINT "workout_template_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_template" ADD CONSTRAINT "workout_template_arc_id_arc_id_fk" FOREIGN KEY ("arc_id") REFERENCES "public"."arc"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "arc_saga_id_idx" ON "arc" USING btree ("saga_id");--> statement-breakpoint
CREATE UNIQUE INDEX "arc_one_current_idx" ON "arc" USING btree ("athlete_id") WHERE "arc"."status" = 'current' AND "arc"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "block_workout_template_id_idx" ON "block" USING btree ("workout_template_id");--> statement-breakpoint
CREATE UNIQUE INDEX "exercise_athlete_normalized_name_idx" ON "exercise" USING btree ("athlete_id","normalized_name") WHERE "exercise"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "prescribed_exercise_block_id_idx" ON "prescribed_exercise" USING btree ("block_id");--> statement-breakpoint
CREATE INDEX "prescribed_exercise_exercise_id_idx" ON "prescribed_exercise" USING btree ("exercise_id");--> statement-breakpoint
CREATE INDEX "workout_template_arc_id_idx" ON "workout_template" USING btree ("arc_id");