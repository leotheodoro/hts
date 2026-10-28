ALTER TABLE "arc" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "athlete" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "battle" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "block" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "exercise" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "logged_round" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "logged_set" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "prescribed_exercise" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "saga" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "session" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;--> statement-breakpoint
ALTER TABLE "workout_template" ADD COLUMN "server_updated_at" timestamp with time zone DEFAULT date_trunc('milliseconds', now()) NOT NULL;