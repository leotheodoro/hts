-- Monthly arcs (#210, docs/decisions/0035): calendar months of an arc, null for every other arc.
ALTER TABLE "arc" ADD COLUMN "months" jsonb;
