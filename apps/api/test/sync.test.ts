import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import {
  arc,
  athlete,
  block,
  exercise,
  loggedSet,
  prescribedExercise,
  saga,
  session,
  workoutTemplate,
} from "../src/db/schema.js";
import { createTestDb, testApiToken } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db, apiToken: testApiToken });
const headers = { authorization: `Bearer ${testApiToken}`, "content-type": "application/json" };
const athletes: string[] = [];

afterAll(async () => {
  if (athletes.length > 0) {
    for (const table of [
      loggedSet,
      session,
      prescribedExercise,
      exercise,
      block,
      workoutTemplate,
      arc,
      saga,
    ]) {
      await db.delete(table).where(inArray(table.athleteId, athletes));
    }
    await db.delete(athlete).where(inArray(athlete.id, athletes));
  }
  await close();
});

const iso = (ms: number) => new Date(ms).toISOString();

/** A device-side snapshot: one athlete, plan and session, as the app sends it. */
function deviceRows() {
  const athleteId = uuidv7();
  athletes.push(athleteId);
  const t = Date.UTC(2026, 10, 2, 12);
  const base = { athlete_id: athleteId, created_at: iso(t), updated_at: iso(t), deleted_at: null };
  const ids = {
    saga: uuidv7(),
    arc: uuidv7(),
    template: uuidv7(),
    block: uuidv7(),
    exercise: uuidv7(),
    prescribed: uuidv7(),
    session: uuidv7(),
    set: uuidv7(),
  };
  const changes = {
    athlete: [
      {
        id: athleteId,
        display_name: "Leo",
        default_rest_seconds: 90,
        created_at: iso(t),
        updated_at: iso(t),
        deleted_at: null,
      },
    ],
    saga: [{ ...base, id: ids.saga, year: 2026, name: "Saga 2026" }],
    arc: [
      {
        ...base,
        id: ids.arc,
        saga_id: ids.saga,
        name: "Recrutamento",
        kanji: "募",
        program: null,
        kind: "normal",
        weeks: 2,
        start_date: "2026-11-02",
        status: "current",
        position: 0,
        count_reset_at: null,
      },
    ],
    workout_template: [
      {
        ...base,
        id: ids.template,
        arc_id: ids.arc,
        source_template_id: null,
        letter: "A",
        name: "Linha de Frente",
        focus: null,
        position: 0,
      },
    ],
    block: [
      {
        ...base,
        id: ids.block,
        workout_template_id: ids.template,
        kind: "strength",
        attributes: ["strength"],
        duration_minutes: null,
        position: 0,
      },
    ],
    exercise: [
      {
        ...base,
        id: ids.exercise,
        name: "Supino",
        normalized_name: "supino",
        default_attribute: "strength",
        unit: "reps",
        per_side: false,
      },
    ],
    prescribed_exercise: [
      {
        ...base,
        id: ids.prescribed,
        block_id: ids.block,
        exercise_id: ids.exercise,
        sets_min: 3,
        sets_max: 3,
        targets: [{ type: "fixed", value: 8 }],
        rest_seconds: null,
        position: 0,
      },
    ],
    session: [
      {
        ...base,
        id: ids.session,
        arc_id: ids.arc,
        workout_template_id: ids.template,
        status: "completed",
        started_at: iso(t),
        finished_at: iso(t + 3_600_000),
        local_date: "2026-11-02",
        plan_snapshot: {
          workoutTemplateId: ids.template,
          letter: "A",
          name: "Linha de Frente",
          focus: null,
          blocks: [],
        },
      },
    ],
    logged_set: [
      {
        ...base,
        id: ids.set,
        session_id: ids.session,
        prescribed_exercise_id: ids.prescribed,
        exercise_id: ids.exercise,
        set_number: 1,
        weight_kg: "62.5",
        reps: 8,
        seconds: null,
        meters: null,
        completed: true,
        completed_at: iso(t + 60_000),
      },
    ],
  };
  return { athleteId, ids, changes, t };
}

const pushChanges = (changes: unknown) =>
  app.request("/v1/sync/push", { method: "POST", headers, body: JSON.stringify({ changes }) });

const pullSince = async (since?: string) => {
  const res = await app.request(
    `/v1/sync/pull${since ? `?since=${encodeURIComponent(since)}` : ""}`,
    { headers },
  );
  expect(res.status).toBe(200);
  return (await res.json()) as {
    cursor: string | null;
    changes: Record<string, Record<string, unknown>[]>;
  };
};

describe("sync", () => {
  it("pushes a whole device snapshot and pulls it back in the same format", async () => {
    const { ids, changes } = deviceRows();
    const res = await pushChanges(changes);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ applied: 9 });

    const pulled = await pullSince();
    const set = pulled.changes.logged_set?.find((row) => row.id === ids.set);
    expect(set).toMatchObject({
      weight_kg: "62.50",
      reps: 8,
      completed: true,
      completed_at: changes.logged_set[0]?.completed_at,
    });
    const block = pulled.changes.block?.find((row) => row.id === ids.block);
    expect(block?.attributes).toEqual(["strength"]);
    expect(pulled.changes.arc?.find((row) => row.id === ids.arc)?.start_date).toBe("2026-11-02");
    expect(Object.keys(set ?? {})).not.toContain("server_updated_at");
    expect(pulled.cursor).not.toBeNull();
  });

  it("keeps the newer row: last write wins by updated_at", async () => {
    const { athleteId, changes, t } = deviceRows();
    await pushChanges(changes);
    const newer = { ...changes.athlete[0], display_name: "Leo Novo", updated_at: iso(t + 10_000) };
    await pushChanges({ athlete: [newer] });
    const older = { ...changes.athlete[0], display_name: "Leo Velho", updated_at: iso(t + 5_000) };
    await pushChanges({ athlete: [older] });
    const [stored] = await db.select().from(athlete).where(eq(athlete.id, athleteId));
    expect(stored?.displayName).toBe("Leo Novo");
  });

  it("pulls only rows written after the cursor", async () => {
    const first = deviceRows();
    await pushChanges(first.changes);
    const { cursor } = await pullSince();
    expect((await pullSince(cursor ?? undefined)).changes).toEqual({});

    const second = deviceRows();
    await pushChanges({ athlete: second.changes.athlete });
    const after = await pullSince(cursor ?? undefined);
    expect(after.changes.athlete?.map((row) => row.id)).toEqual([second.athleteId]);
    expect(Object.keys(after.changes)).toEqual(["athlete"]);
  });

  it("rejects unknown tables and requests without the token", async () => {
    expect((await pushChanges({ nope: [] })).status).toBe(400);
    expect((await app.request("/v1/sync/pull")).status).toBe(401);
  });
});
