CREATE TABLE "athlete" (
	"id" uuid PRIMARY KEY NOT NULL,
	"display_name" text NOT NULL,
	"default_rest_seconds" integer DEFAULT 90 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone
);
