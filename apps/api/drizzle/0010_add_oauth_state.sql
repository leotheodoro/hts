CREATE TABLE "oauth_state" (
	"state" text PRIMARY KEY NOT NULL,
	"account_id" uuid NOT NULL,
	"provider" text NOT NULL,
	"code_verifier" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "oauth_state" ADD CONSTRAINT "oauth_state_account_id_account_id_fk" FOREIGN KEY ("account_id") REFERENCES "public"."account"("id") ON DELETE no action ON UPDATE no action;