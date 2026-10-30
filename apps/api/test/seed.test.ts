import { and, eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import {
  account,
  arc,
  athlete,
  block,
  exercise,
  prescribedExercise,
  season,
  workoutTemplate,
} from "../src/db/schema.js";
import { seedAccount } from "../src/seed/account.js";
import { importStarterPlan, StarterPlanFileSchema } from "../src/seed/starter-plan.js";
import { createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
const athletes: string[] = [];

afterAll(async () => {
  await removeAccounts(db, athletes);
  if (athletes.length > 0) {
    for (const table of [prescribedExercise, exercise, block, workoutTemplate, arc, season]) {
      await db.delete(table).where(inArray(table.athleteId, athletes));
    }
    await db.delete(athlete).where(inArray(athlete.id, athletes));
  }
  await close();
});

const plan = StarterPlanFileSchema.parse({
  seasons: [
    {
      name: "Jiu-Jitsu",
      arcs: [
        {
          name: "Base Volume 1",
          kanji: "基",
          weeks: 2,
          templates: [
            {
              name: "Push",
              focus: "Superiores",
              blocks: [
                {
                  kind: "activation",
                  attributes: ["mobility"],
                  exercises: [
                    {
                      name: "Rotação Externa de Ombros",
                      sets: "2",
                      target: "12/12",
                      video: "https://www.youtube.com/shorts/B6CUO_zF32Q",
                    },
                  ],
                },
              ],
            },
            {
              name: "Pernas",
              blocks: [
                {
                  kind: "fight_round",
                  attributes: ["conditioning", "strength"],
                  exercises: [{ name: "Farmer Carry", unit: "meters", sets: "1", target: "20" }],
                },
              ],
            },
          ],
        },
        {
          name: "Base Volume 2",
          kanji: "礎",
          weeks: 2,
          templates: [
            {
              name: "Força",
              blocks: [
                {
                  kind: "strength",
                  attributes: ["strength"],
                  exercises: [{ name: "Supino", sets: "3 a 4", target: "6-6-3-3" }],
                },
              ],
            },
          ],
        },
      ],
    },
  ],
  arcs: [
    {
      name: "Mobilidade",
      kanji: "柔",
      templates: [
        {
          name: "Diária",
          blocks: [
            {
              kind: "mobility",
              attributes: ["mobility"],
              exercises: [{ name: "Pigeon", unit: "minutes", sets: "1", target: "1/1" }],
            },
          ],
        },
      ],
    },
  ],
});

async function seeded() {
  const tag = uuidv7().slice(-12);
  const credentials = {
    name: "Leonardo Theodoro",
    username: `leo-${tag}`,
    email: `leo-${tag}@hts.test`,
    password: `pw-${tag}`,
  };
  const ids = await seedAccount(db, credentials);
  athletes.push(ids.athleteId);
  return { ...ids, ...credentials };
}

const login = (identifier: string, password: string) =>
  app.request("/v1/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ identifier, password }),
  });

describe("seedAccount", () => {
  it("seeds the account once and logs in", async () => {
    const leo = await seeded();
    const again = await seedAccount(db, { ...leo, password: "new-password" });
    expect(again).toEqual({ accountId: leo.accountId, athleteId: leo.athleteId });
    const rows = await db.select().from(account).where(eq(account.athleteId, leo.athleteId));
    expect(rows).toHaveLength(1);
    expect((await login(leo.username, "new-password")).status).toBe(200);
    expect((await login(leo.username, leo.password)).status).toBe(401);
    const [stored] = await db.select().from(athlete).where(eq(athlete.id, leo.athleteId));
    expect(stored?.displayName).toBe("Leonardo Theodoro");
  });
});

describe("importStarterPlan", () => {
  it("imports seasons, arcs and templates like the app did", async () => {
    const leo = await seeded();
    const result = await importStarterPlan(db, leo.athleteId, plan, "2026-11-02");
    expect(result).toEqual({ arcsAdded: 3, videosFilled: 1 });

    const [jiuJitsu] = await db.select().from(season).where(eq(season.athleteId, leo.athleteId));
    expect(jiuJitsu).toMatchObject({ name: "Jiu-Jitsu", active: true, position: 0 });
    const arcs = await db
      .select()
      .from(arc)
      .where(eq(arc.athleteId, leo.athleteId))
      .orderBy(arc.position);
    const byName = Object.fromEntries(arcs.map((a) => [a.name, a]));
    expect(byName["Base Volume 1"]).toMatchObject({
      status: "current",
      kind: "normal",
      weeks: 2,
      startDate: "2026-11-02",
      kanji: "基",
      seasonId: jiuJitsu?.id,
    });
    expect(byName["Base Volume 2"]).toMatchObject({ status: "queued", position: 1 });
    expect(byName.Mobilidade).toMatchObject({
      status: "queued",
      kind: "filler",
      weeks: null,
      startDate: null,
      seasonId: null,
    });

    const templates = await db
      .select()
      .from(workoutTemplate)
      .where(eq(workoutTemplate.arcId, byName["Base Volume 1"]?.id ?? ""))
      .orderBy(workoutTemplate.position);
    expect(templates.map((t) => [t.letter, t.name, t.focus])).toEqual([
      ["A", "Push", "Superiores"],
      ["B", "Pernas", null],
    ]);
    const [round] = await db
      .select()
      .from(block)
      .where(eq(block.workoutTemplateId, templates[1]?.id ?? ""));
    expect(round).toMatchObject({ kind: "fight_round", durationMinutes: 8, position: 0 });

    const exercises = await db.select().from(exercise).where(eq(exercise.athleteId, leo.athleteId));
    const rotation = exercises.find((e) => e.normalizedName === "rotacao externa de ombros");
    expect(rotation).toMatchObject({
      perSide: true,
      unit: "reps",
      defaultAttribute: "mobility",
      videoUrl: "https://www.youtube.com/shorts/B6CUO_zF32Q",
    });
    expect(exercises.find((e) => e.name === "Farmer Carry")?.unit).toBe("meters");

    const [supino] = await db
      .select()
      .from(prescribedExercise)
      .innerJoin(exercise, eq(exercise.id, prescribedExercise.exerciseId))
      .where(and(eq(exercise.athleteId, leo.athleteId), eq(exercise.name, "Supino")));
    expect(supino?.prescribed_exercise).toMatchObject({
      setsMin: 3,
      setsMax: 4,
      position: 0,
      targets: [
        { type: "fixed", value: 6 },
        { type: "fixed", value: 6 },
        { type: "fixed", value: 3 },
        { type: "fixed", value: 3 },
      ],
    });
  });

  it("is additive by name", async () => {
    const leo = await seeded();
    await importStarterPlan(db, leo.athleteId, plan, "2026-11-02");
    expect(await importStarterPlan(db, leo.athleteId, plan, "2026-11-09")).toEqual({
      arcsAdded: 0,
      videosFilled: 0,
    });
  });

  it("refuses a template the notation cannot read", async () => {
    const leo = await seeded();
    const broken = StarterPlanFileSchema.parse({
      arcs: [
        {
          name: "Quebrado",
          kanji: "壊",
          templates: [
            {
              name: "Ruim",
              blocks: [
                {
                  kind: "strength",
                  attributes: ["strength"],
                  exercises: [{ name: "Supino", sets: "3", target: "pesado" }],
                },
              ],
            },
          ],
        },
      ],
    });
    await expect(importStarterPlan(db, leo.athleteId, broken, "2026-11-02")).rejects.toThrow(
      /Ruim/,
    );
    expect(await db.select().from(arc).where(eq(arc.athleteId, leo.athleteId))).toEqual([]);
  });

  it("pull returns the imported plan", async () => {
    const leo = await seeded();
    await importStarterPlan(db, leo.athleteId, plan, "2026-11-02");
    const { token } = (await (await login(leo.email, leo.password)).json()) as { token: string };
    const res = await app.request(`/v1/sync/pull?athleteId=${leo.athleteId}`, {
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    const { changes } = (await res.json()) as { changes: Record<string, unknown[]> };
    for (const table of [
      "athlete",
      "season",
      "arc",
      "workout_template",
      "block",
      "exercise",
      "prescribed_exercise",
    ]) {
      expect(changes[table]?.length ?? 0).toBeGreaterThan(0);
    }
  });
});
