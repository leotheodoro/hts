CREATE TABLE "arc_pause" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"arc_id" uuid NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL
);
--> statement-breakpoint
ALTER TABLE "arc_pause" ADD CONSTRAINT "arc_pause_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "arc_pause" ADD CONSTRAINT "arc_pause_arc_id_arc_id_fk" FOREIGN KEY ("arc_id") REFERENCES "public"."arc"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "arc_pause_arc_id_idx" ON "arc_pause" USING btree ("arc_id");