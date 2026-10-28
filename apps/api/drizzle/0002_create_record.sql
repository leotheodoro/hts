CREATE TYPE "public"."session_status" AS ENUM('in_progress', 'completed');--> statement-breakpoint
CREATE TABLE "logged_round" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"block_id" uuid NOT NULL,
	"rounds_completed" smallint DEFAULT 0 NOT NULL,
	"weights" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "logged_set" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"session_id" uuid NOT NULL,
	"prescribed_exercise_id" uuid NOT NULL,
	"exercise_id" uuid NOT NULL,
	"set_number" smallint NOT NULL,
	"weight_kg" numeric(6, 2),
	"reps" smallint,
	"seconds" integer,
	"meters" numeric(8, 2),
	"completed" boolean DEFAULT false NOT NULL,
	"completed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "session" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"arc_id" uuid NOT NULL,
	"workout_template_id" uuid NOT NULL,
	"status" "session_status" DEFAULT 'in_progress' NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"finished_at" timestamp with time zone,
	"local_date" date NOT NULL,
	"plan_snapshot" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "logged_round" ADD CONSTRAINT "logged_round_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_round" ADD CONSTRAINT "logged_round_session_id_session_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."session"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_round" ADD CONSTRAINT "logged_round_block_id_block_id_fk" FOREIGN KEY ("block_id") REFERENCES "public"."block"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_set" ADD CONSTRAINT "logged_set_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_set" ADD CONSTRAINT "logged_set_session_id_session_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."session"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_set" ADD CONSTRAINT "logged_set_prescribed_exercise_id_prescribed_exercise_id_fk" FOREIGN KEY ("prescribed_exercise_id") REFERENCES "public"."prescribed_exercise"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "logged_set" ADD CONSTRAINT "logged_set_exercise_id_exercise_id_fk" FOREIGN KEY ("exercise_id") REFERENCES "public"."exercise"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_arc_id_arc_id_fk" FOREIGN KEY ("arc_id") REFERENCES "public"."arc"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_workout_template_id_workout_template_id_fk" FOREIGN KEY ("workout_template_id") REFERENCES "public"."workout_template"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "logged_round_session_id_idx" ON "logged_round" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "logged_set_session_id_idx" ON "logged_set" USING btree ("session_id");--> statement-breakpoint
CREATE INDEX "logged_set_exercise_id_idx" ON "logged_set" USING btree ("exercise_id");--> statement-breakpoint
CREATE INDEX "session_athlete_started_at_idx" ON "session" USING btree ("athlete_id","started_at");--> statement-breakpoint
CREATE INDEX "session_workout_template_id_idx" ON "session" USING btree ("workout_template_id");--> statement-breakpoint
CREATE UNIQUE INDEX "session_one_in_progress_idx" ON "session" USING btree ("athlete_id") WHERE "session"."status" = 'in_progress' AND "session"."deleted_at" IS NULL;