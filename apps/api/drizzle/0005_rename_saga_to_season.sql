-- Saga becomes Temporada (season): a named sequence of arcs, one active per athlete (docs/decisions/0029).
ALTER TABLE "saga" RENAME TO "season";--> statement-breakpoint
ALTER TABLE "season" RENAME CONSTRAINT "saga_pkey" TO "season_pkey";--> statement-breakpoint
ALTER TABLE "season" RENAME CONSTRAINT "saga_athlete_id_athlete_id_fk" TO "season_athlete_id_athlete_id_fk";--> statement-breakpoint
ALTER TABLE "season" DROP COLUMN "year";--> statement-breakpoint
ALTER TABLE "season" ADD COLUMN "position" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "season" ADD COLUMN "active" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "arc" RENAME COLUMN "saga_id" TO "season_id";--> statement-breakpoint
ALTER TABLE "arc" ALTER COLUMN "season_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "arc" RENAME CONSTRAINT "arc_saga_id_saga_id_fk" TO "arc_season_id_season_id_fk";--> statement-breakpoint
ALTER INDEX "arc_saga_id_idx" RENAME TO "arc_season_id_idx";--> statement-breakpoint
ALTER TABLE "battle" RENAME COLUMN "saga_id" TO "season_id";--> statement-breakpoint
ALTER TABLE "battle" ALTER COLUMN "season_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "battle" RENAME CONSTRAINT "battle_saga_id_saga_id_fk" TO "battle_season_id_season_id_fk";--> statement-breakpoint
-- Filler arcs (Manutenção) are free: they belong to no season.
UPDATE "arc" SET "season_id" = NULL, "updated_at" = date_trunc('milliseconds', now()),
  "server_updated_at" = date_trunc('milliseconds', now())
  WHERE "kind" = 'filler' AND "season_id" IS NOT NULL;--> statement-breakpoint
-- The season holding the current arc becomes the active one.
UPDATE "season" SET "active" = true, "updated_at" = date_trunc('milliseconds', now()),
  "server_updated_at" = date_trunc('milliseconds', now())
  WHERE "id" IN (SELECT "season_id" FROM "arc" WHERE "status" = 'current' AND "deleted_at" IS NULL AND "season_id" IS NOT NULL);--> statement-breakpoint
CREATE UNIQUE INDEX "season_one_active_idx" ON "season" USING btree ("athlete_id") WHERE "season"."active" AND "season"."deleted_at" IS NULL;
