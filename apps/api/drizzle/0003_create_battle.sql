CREATE TYPE "public"."battle_result" AS ENUM('gold', 'silver', 'bronze', 'participation');--> statement-breakpoint
CREATE TABLE "battle" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"saga_id" uuid NOT NULL,
	"name" text NOT NULL,
	"date" date NOT NULL,
	"result" "battle_result",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "battle" ADD CONSTRAINT "battle_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "battle" ADD CONSTRAINT "battle_saga_id_saga_id_fk" FOREIGN KEY ("saga_id") REFERENCES "public"."saga"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "battle_athlete_date_idx" ON "battle" USING btree ("athlete_id","date");