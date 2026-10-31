CREATE TABLE "imported_activity" (
	"id" uuid PRIMARY KEY NOT NULL,
	"athlete_id" uuid NOT NULL,
	"source" text NOT NULL,
	"external_id" text NOT NULL,
	"activity_type" text NOT NULL,
	"name" text,
	"started_at" timestamp with time zone NOT NULL,
	"duration_seconds" integer NOT NULL,
	"distance_meters" numeric(9, 2),
	"average_heart_rate" smallint,
	"calories" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL
);
--> statement-breakpoint
CREATE TABLE "integration_connection" (
	"id" uuid PRIMARY KEY NOT NULL,
	"account_id" uuid NOT NULL,
	"provider" text NOT NULL,
	"external_user_id" text NOT NULL,
	"access_token" text,
	"refresh_token" text,
	"token_expires_at" timestamp with time zone,
	"connected_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_activity_at" timestamp with time zone
);
--> statement-breakpoint
ALTER TABLE "imported_activity" ADD CONSTRAINT "imported_activity_athlete_id_athlete_id_fk" FOREIGN KEY ("athlete_id") REFERENCES "public"."athlete"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "integration_connection" ADD CONSTRAINT "integration_connection_account_id_account_id_fk" FOREIGN KEY ("account_id") REFERENCES "public"."account"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "imported_activity_source_external_id_idx" ON "imported_activity" USING btree ("source","external_id");--> statement-breakpoint
CREATE INDEX "imported_activity_athlete_started_at_idx" ON "imported_activity" USING btree ("athlete_id","started_at");--> statement-breakpoint
CREATE UNIQUE INDEX "integration_connection_provider_user_idx" ON "integration_connection" USING btree ("provider","external_user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "integration_connection_account_provider_idx" ON "integration_connection" USING btree ("account_id","provider");