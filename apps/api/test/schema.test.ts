import { readFileSync } from "node:fs";
import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { normalizeExerciseName } from "../src/db/exercise-name.js";
import {
  arc,
  athlete,
  block,
  exercise,
  loggedRound,
  loggedSet,
  prescribedExercise,
  saga,
  session,
  workoutTemplate,
} from "../src/db/schema.js";
import { PlanSnapshotSchema } from "../src/db/snapshot.js";
import { SetTargetSchema, targetsFitSets } from "../src/db/targets.js";
import { createTestDb } from "./db.js";

const { db, close } = createTestDb();
const athleteIds: string[] = [];

afterAll(async () => {
  if (athleteIds.length > 0) {
    // Children first: the schema uses plain foreign keys (soft delete), no cascades.
    await db.delete(loggedSet).where(inArray(loggedSet.athleteId, athleteIds));
    await db.delete(loggedRound).where(inArray(loggedRound.athleteId, athleteIds));
    await db.delete(session).where(inArray(session.athleteId, athleteIds));
    await db.delete(prescribedExercise).where(inArray(prescribedExercise.athleteId, athleteIds));
    await db.delete(exercise).where(inArray(exercise.athleteId, athleteIds));
    await db.delete(block).where(inArray(block.athleteId, athleteIds));
    await db.delete(workoutTemplate).where(inArray(workoutTemplate.athleteId, athleteIds));
    await db.delete(arc).where(inArray(arc.athleteId, athleteIds));
    await db.delete(saga).where(inArray(saga.athleteId, athleteIds));
    await db.delete(athlete).where(inArray(athlete.id, athleteIds));
  }
  await close();
});

async function seedAthlete() {
  const athleteId = uuidv7();
  athleteIds.push(athleteId);
  await db.insert(athlete).values({ id: athleteId, displayName: "Leo" });
  const sagaId = uuidv7();
  await db.insert(saga).values({ id: sagaId, athleteId, year: 2026, name: "Saga 2026" });
  return { athleteId, sagaId };
}

describe("plan schema", () => {
  it("stores a full plan: arc, template, block and prescribed exercise", async () => {
    const { athleteId, sagaId } = await seedAthlete();
    const arcId = uuidv7();
    const templateId = uuidv7();
    const blockId = uuidv7();
    const exerciseId = uuidv7();
    await db.insert(arc).values({
      id: arcId,
      athleteId,
      sagaId,
      name: "Recrutamento",
      kanji: "募",
      weeks: 2,
      startDate: "2026-11-02",
      status: "current",
      position: 0,
    });
    await db.insert(workoutTemplate).values({
      id: templateId,
      athleteId,
      arcId,
      letter: "A",
      name: "Linha de Frente",
      position: 0,
    });
    await db.insert(block).values({
      id: blockId,
      athleteId,
      workoutTemplateId: templateId,
      kind: "strength",
      attributes: ["strength"],
      position: 0,
    });
    await db.insert(exercise).values({
      id: exerciseId,
      athleteId,
      name: "Zercher Squat",
      normalizedName: normalizeExerciseName("Zercher Squat"),
      defaultAttribute: "strength",
    });
    const targets = [
      { type: "fixed", value: 6 },
      { type: "fixed", value: 6 },
      { type: "fixed", value: 3 },
      { type: "fixed", value: 3 },
    ] as const;
    await db.insert(prescribedExercise).values({
      id: uuidv7(),
      athleteId,
      blockId,
      exerciseId,
      setsMin: 4,
      setsMax: 4,
      targets: [...targets],
      position: 0,
    });

    const [row] = await db
      .select()
      .from(prescribedExercise)
      .where(eq(prescribedExercise.blockId, blockId));
    expect(row?.targets).toEqual(targets);
    const [stored] = await db.select().from(arc).where(eq(arc.id, arcId));
    expect(stored?.startDate).toBe("2026-11-02");
  });

  it("allows only one current arc per athlete", async () => {
    const { athleteId, sagaId } = await seedAthlete();
    const base = { athleteId, sagaId, name: "Arco", status: "current" as const };
    await db.insert(arc).values({ ...base, id: uuidv7(), position: 0 });
    await expect(db.insert(arc).values({ ...base, id: uuidv7(), position: 1 })).rejects.toThrow();
  });

  it("rejects a duplicate exercise name after normalization, unless the first is deleted", async () => {
    const { athleteId } = await seedAthlete();
    const first = uuidv7();
    await db.insert(exercise).values({
      id: first,
      athleteId,
      name: "Barra Fixa",
      normalizedName: normalizeExerciseName("Barra Fixa"),
    });
    const duplicate = {
      athleteId,
      name: "barra  fixa",
      normalizedName: normalizeExerciseName("barra  fixa"),
    };
    await expect(db.insert(exercise).values({ ...duplicate, id: uuidv7() })).rejects.toThrow();
    await db.update(exercise).set({ deletedAt: new Date() }).where(eq(exercise.id, first));
    await db.insert(exercise).values({ ...duplicate, id: uuidv7() });
  });
});

describe("SetTarget", () => {
  it("accepts the three target kinds and rejects inverted ranges", () => {
    expect(SetTargetSchema.parse({ type: "fixed", value: 8 })).toEqual({ type: "fixed", value: 8 });
    expect(SetTargetSchema.parse({ type: "range", min: 10, max: 20 }).type).toBe("range");
    expect(SetTargetSchema.parse({ type: "max" })).toEqual({ type: "max" });
    expect(SetTargetSchema.safeParse({ type: "range", min: 20, max: 10 }).success).toBe(false);
  });

  it("needs one target for all sets or one per set", () => {
    expect(targetsFitSets([{ type: "fixed", value: 8 }], 3)).toBe(true);
    expect(targetsFitSets(Array(4).fill({ type: "fixed", value: 6 }), 4)).toBe(true);
    expect(targetsFitSets(Array(2).fill({ type: "fixed", value: 6 }), 4)).toBe(false);
  });
});

describe("normalizeExerciseName (shared fixture)", () => {
  const url = new URL("../../../packages/fixtures/normalize-exercise-name.json", import.meta.url);
  const fixture = JSON.parse(readFileSync(url, "utf8")) as {
    cases: { name: string; input: { name: string }; expected: { normalized: string } }[];
  };
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(normalizeExerciseName(input.name)).toBe(expected.normalized);
  });
});

describe("record schema", () => {
  async function seedTemplate() {
    const { athleteId, sagaId } = await seedAthlete();
    const ids = {
      arcId: uuidv7(),
      templateId: uuidv7(),
      blockId: uuidv7(),
      exerciseId: uuidv7(),
      prescribedId: uuidv7(),
    };
    await db.insert(arc).values({ id: ids.arcId, athleteId, sagaId, name: "Arco", position: 0 });
    await db.insert(workoutTemplate).values({
      id: ids.templateId,
      athleteId,
      arcId: ids.arcId,
      letter: "A",
      name: "Linha de Frente",
      position: 0,
    });
    await db.insert(block).values({
      id: ids.blockId,
      athleteId,
      workoutTemplateId: ids.templateId,
      kind: "strength",
      attributes: ["strength"],
      position: 0,
    });
    await db.insert(exercise).values({
      id: ids.exerciseId,
      athleteId,
      name: "Supino",
      normalizedName: "supino",
    });
    await db.insert(prescribedExercise).values({
      id: ids.prescribedId,
      athleteId,
      blockId: ids.blockId,
      exerciseId: ids.exerciseId,
      setsMin: 3,
      setsMax: 3,
      targets: [{ type: "fixed", value: 8 }],
      position: 0,
    });
    const snapshot = PlanSnapshotSchema.parse({
      workoutTemplateId: ids.templateId,
      letter: "A",
      name: "Linha de Frente",
      focus: null,
      blocks: [
        {
          blockId: ids.blockId,
          kind: "strength",
          attributes: ["strength"],
          durationMinutes: null,
          exercises: [
            {
              prescribedExerciseId: ids.prescribedId,
              exerciseId: ids.exerciseId,
              name: "Supino",
              unit: "reps",
              perSide: false,
              setsMin: 3,
              setsMax: 3,
              targets: [{ type: "fixed", value: 8 }],
              restSeconds: null,
            },
          ],
        },
      ],
    });
    return { athleteId, snapshot, ...ids };
  }

  it("stores a session with its plan snapshot and exact decimal loads", async () => {
    const t = await seedTemplate();
    const sessionId = uuidv7();
    await db.insert(session).values({
      id: sessionId,
      athleteId: t.athleteId,
      arcId: t.arcId,
      workoutTemplateId: t.templateId,
      startedAt: new Date("2026-11-02T10:00:00Z"),
      localDate: "2026-11-02",
      planSnapshot: t.snapshot,
    });
    await db.insert(loggedSet).values({
      id: uuidv7(),
      athleteId: t.athleteId,
      sessionId,
      prescribedExerciseId: t.prescribedId,
      exerciseId: t.exerciseId,
      setNumber: 1,
      weightKg: "62.5",
      reps: 8,
      completed: true,
      completedAt: new Date("2026-11-02T10:05:00Z"),
    });
    await db.insert(loggedRound).values({
      id: uuidv7(),
      athleteId: t.athleteId,
      sessionId,
      blockId: t.blockId,
      roundsCompleted: 3,
      weights: [{ exerciseId: t.exerciseId, weightKg: "24" }],
    });

    const [stored] = await db.select().from(session).where(eq(session.id, sessionId));
    expect(PlanSnapshotSchema.parse(stored?.planSnapshot)).toEqual(t.snapshot);
    expect(stored?.status).toBe("in_progress");
    const [set] = await db.select().from(loggedSet).where(eq(loggedSet.sessionId, sessionId));
    expect(set?.weightKg).toBe("62.50");
  });

  it("allows only one session in progress per athlete", async () => {
    const t = await seedTemplate();
    const base = {
      athleteId: t.athleteId,
      arcId: t.arcId,
      workoutTemplateId: t.templateId,
      startedAt: new Date(),
      localDate: "2026-11-02",
      planSnapshot: t.snapshot,
    };
    await db.insert(session).values({ ...base, id: uuidv7() });
    await expect(db.insert(session).values({ ...base, id: uuidv7() })).rejects.toThrow();
    await db.insert(session).values({ ...base, id: uuidv7(), status: "completed" });
  });
});
