import { and, eq, isNull, max, sql } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { normalizeExerciseName } from "../db/exercise-name.js";
import {
  arc,
  arcKind,
  attribute,
  block,
  blockKind,
  exercise,
  exerciseUnit,
  prescribedExercise,
  season,
  workoutTemplate,
} from "../db/schema.js";
import { parseSets, parseTarget } from "./notation.js";

// The coach's programs (apps/api/seed/starter-plan.json, out of git: the content is licensed).
// Same format and rules as the importer the app used to run (StarterPlan.swift, ArcService,
// TemplateService): additive by name, so new arcs can be appended to the file later. Updates stamp
// server_updated_at, the pull cursor, so devices that already synced receive them.

const ExerciseSeed = z.object({
  name: z.string().min(1),
  unit: z.enum(exerciseUnit.enumValues).optional(),
  /** "3" or "3 a 4". */
  sets: z.string(),
  /** "8", "6-6-3-3", "12/12", "20 s", "máx". */
  target: z.string(),
  restSeconds: z.number().int().positive().optional(),
  /** The coach's YouTube link. */
  video: z.string().optional(),
});

const BlockSeed = z.object({
  kind: z.enum(blockKind.enumValues),
  attributes: z.array(z.enum(attribute.enumValues)),
  durationMinutes: z.number().int().positive().optional(),
  exercises: z.array(ExerciseSeed),
});

const TemplateSeed = z.object({
  name: z.string().min(1),
  focus: z.string().optional(),
  blocks: z.array(BlockSeed),
});

const ArcSeed = z.object({
  name: z.string().min(1),
  /** Every arc has a kanji (#79). */
  kanji: z.string().trim().min(1),
  kind: z.enum(arcKind.enumValues).optional(),
  weeks: z.number().int().positive().optional(),
  templates: z.array(TemplateSeed),
});

export const StarterPlanFileSchema = z.object({
  seasons: z.array(z.object({ name: z.string().min(1), arcs: z.array(ArcSeed) })).default([]),
  /** Free arcs, always available: imported as filler. */
  arcs: z.array(ArcSeed).default([]),
});

export type StarterPlanFile = z.infer<typeof StarterPlanFileSchema>;
type Tx = Parameters<Parameters<Db["transaction"]>[0]>[0];

/** "A", "B", … "Z", "AA". */
function letter(index: number): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  return index < 26
    ? (alphabet[index] as string)
    : letter(Math.floor(index / 26) - 1) + alphabet[index % 26];
}

/**
 * Adds every season and arc of the plan that the athlete does not have yet (arcs by name inside
 * their season, or among free arcs), then fills the catalog videos that are still empty. Existing
 * arcs are left untouched. All or nothing: a template the notation cannot read aborts the import.
 */
export async function importStarterPlan(
  db: Db,
  athleteId: string,
  plan: StarterPlanFile,
  today: string,
): Promise<{ arcsAdded: number; videosFilled: number }> {
  return db.transaction(async (tx) => {
    const now = new Date();
    let arcsAdded = 0;
    for (const seasonSeed of plan.seasons) {
      const seasonId = await findOrCreateSeason(tx, athleteId, seasonSeed.name, now);
      for (const seed of seasonSeed.arcs) {
        if (await addArc(tx, athleteId, seed, seasonId, today, now)) arcsAdded++;
      }
    }
    for (const seed of plan.arcs) {
      if (await addArc(tx, athleteId, { ...seed, kind: "filler" }, null, today, now)) arcsAdded++;
    }
    return { arcsAdded, videosFilled: await fillVideos(tx, athleteId, plan, now) };
  });
}

async function findOrCreateSeason(tx: Tx, athleteId: string, name: string, now: Date) {
  const live = and(eq(season.athleteId, athleteId), isNull(season.deletedAt));
  const [existing] = await tx
    .select()
    .from(season)
    .where(and(live, eq(season.name, name)));
  if (existing) return existing.id;
  const [{ last } = { last: null }] = await tx
    .select({ last: max(season.position) })
    .from(season)
    .where(live);
  const [active] = await tx
    .select({ id: season.id })
    .from(season)
    .where(and(live, eq(season.active, true)));
  const id = uuidv7();
  await tx.insert(season).values({
    id,
    athleteId,
    name,
    position: (last ?? -1) + 1,
    active: !active,
    createdAt: now,
    updatedAt: now,
  });
  return id;
}

async function addArc(
  tx: Tx,
  athleteId: string,
  seed: z.infer<typeof ArcSeed>,
  seasonId: string | null,
  today: string,
  now: Date,
): Promise<boolean> {
  const sameSeason = seasonId ? eq(arc.seasonId, seasonId) : isNull(arc.seasonId);
  const live = and(eq(arc.athleteId, athleteId), isNull(arc.deletedAt));
  const [existing] = await tx
    .select({ id: arc.id })
    .from(arc)
    .where(and(live, sameSeason, eq(arc.name, seed.name.trim())));
  if (existing) return false;

  const kind = seed.kind ?? "normal";
  const [current] = await tx
    .select({ id: arc.id })
    .from(arc)
    .where(and(live, eq(arc.status, "current")));
  const [inActiveSeason] = seasonId
    ? await tx
        .select({ id: season.id })
        .from(season)
        .where(and(eq(season.id, seasonId), eq(season.active, true)))
    : [];
  const [{ last } = { last: null }] = await tx
    .select({ last: max(arc.position) })
    .from(arc)
    .where(and(live, sameSeason));
  // Filler arcs are always available and never take the current slot (docs/decisions/0028).
  const becomesCurrent = !current && kind !== "filler" && Boolean(inActiveSeason);
  const hasDuration = kind !== "filler";
  const arcId = uuidv7();
  await tx.insert(arc).values({
    id: arcId,
    athleteId,
    seasonId,
    name: seed.name.trim(),
    kanji: seed.kanji.trim(),
    kind,
    weeks: hasDuration ? (seed.weeks ?? 1) : null,
    startDate: hasDuration ? today : null,
    status: becomesCurrent ? "current" : "queued",
    position: (last ?? -1) + 1,
    createdAt: now,
    updatedAt: now,
  });

  for (const [templateIndex, templateSeed] of seed.templates.entries()) {
    const templateId = uuidv7();
    const focus = templateSeed.focus?.trim();
    await tx.insert(workoutTemplate).values({
      id: templateId,
      athleteId,
      arcId,
      letter: letter(templateIndex),
      name: templateSeed.name.trim(),
      focus: focus ? focus : null,
      position: templateIndex,
      createdAt: now,
      updatedAt: now,
    });
    for (const [blockIndex, blockSeed] of templateSeed.blocks.entries()) {
      const blockId = uuidv7();
      await tx.insert(block).values({
        id: blockId,
        athleteId,
        workoutTemplateId: templateId,
        kind: blockSeed.kind,
        attributes: blockSeed.attributes,
        durationMinutes: blockSeed.kind === "fight_round" ? (blockSeed.durationMinutes ?? 8) : null,
        position: blockIndex,
        createdAt: now,
        updatedAt: now,
      });
      for (const [exerciseIndex, exerciseSeed] of blockSeed.exercises.entries()) {
        const sets = parseSets(exerciseSeed.sets);
        const parsed = sets ? parseTarget(exerciseSeed.target, sets.max) : null;
        if (!sets || !parsed) {
          throw new Error(
            `Invalid template "${templateSeed.name}": ${exerciseSeed.name} ${exerciseSeed.sets} × ${exerciseSeed.target}`,
          );
        }
        const exerciseId = await findOrCreateExercise(
          tx,
          athleteId,
          exerciseSeed.name,
          exerciseSeed.unit ?? "reps",
          parsed.perSide,
          blockSeed.attributes[0] ?? null,
          now,
        );
        await tx.insert(prescribedExercise).values({
          id: uuidv7(),
          athleteId,
          blockId,
          exerciseId,
          setsMin: sets.min,
          setsMax: sets.max,
          targets: parsed.targets,
          restSeconds: exerciseSeed.restSeconds ?? null,
          position: exerciseIndex,
          createdAt: now,
          updatedAt: now,
        });
      }
    }
  }
  return true;
}

/** Catalog exercise by normalized name (docs/decisions/0016); unit and per side follow the plan. */
async function findOrCreateExercise(
  tx: Tx,
  athleteId: string,
  name: string,
  unit: (typeof exerciseUnit.enumValues)[number],
  perSide: boolean,
  defaultAttribute: (typeof attribute.enumValues)[number] | null,
  now: Date,
): Promise<string> {
  const normalizedName = normalizeExerciseName(name);
  const [existing] = await tx
    .select()
    .from(exercise)
    .where(
      and(
        eq(exercise.athleteId, athleteId),
        eq(exercise.normalizedName, normalizedName),
        isNull(exercise.deletedAt),
      ),
    );
  if (existing) {
    if (existing.unit !== unit || (perSide && !existing.perSide)) {
      await tx
        .update(exercise)
        .set({
          unit,
          perSide: existing.perSide || perSide,
          updatedAt: now,
          serverUpdatedAt: sql`date_trunc('milliseconds', now())`,
        })
        .where(eq(exercise.id, existing.id));
    }
    return existing.id;
  }
  const id = uuidv7();
  await tx.insert(exercise).values({
    id,
    athleteId,
    name: name.trim(),
    normalizedName,
    defaultAttribute,
    unit,
    perSide,
    createdAt: now,
    updatedAt: now,
  });
  return id;
}

/** The plan's video for each catalog exercise that has none yet; a link already there is kept. */
async function fillVideos(
  tx: Tx,
  athleteId: string,
  plan: StarterPlanFile,
  now: Date,
): Promise<number> {
  const videos = new Map<string, string>();
  for (const arcSeed of [...plan.seasons.flatMap((s) => s.arcs), ...plan.arcs]) {
    for (const exerciseSeed of arcSeed.templates
      .flatMap((t) => t.blocks)
      .flatMap((b) => b.exercises)) {
      const key = normalizeExerciseName(exerciseSeed.name);
      if (exerciseSeed.video && !videos.has(key)) videos.set(key, exerciseSeed.video);
    }
  }
  let filled = 0;
  for (const [normalizedName, video] of videos) {
    const rows = await tx
      .update(exercise)
      .set({
        videoUrl: video,
        updatedAt: now,
        serverUpdatedAt: sql`date_trunc('milliseconds', now())`,
      })
      .where(
        and(
          eq(exercise.athleteId, athleteId),
          eq(exercise.normalizedName, normalizedName),
          isNull(exercise.videoUrl),
          isNull(exercise.deletedAt),
        ),
      )
      .returning({ id: exercise.id });
    filled += rows.length;
  }
  return filled;
}
