import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import {
  arc,
  athlete,
  block,
  exercise,
  importedActivity,
  loggedSet,
  prescribedExercise,
  season,
  session,
  workoutTemplate,
} from "../src/db/schema.js";
import { createTestAccount, createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
const athletes: string[] = [];

/** An athlete with an account and a session, as after logging in on the device. */
async function signedIn() {
  const leo = await createTestAccount(db);
  athletes.push(leo.athleteId);
  return leo;
}

const headersFor = (token: string) => ({
  authorization: `Bearer ${token}`,
  "content-type": "application/json",
});

afterAll(async () => {
  await removeAccounts(db, athletes);
  if (athletes.length > 0) {
    for (const table of [
      importedActivity,
      loggedSet,
      session,
      prescribedExercise,
      exercise,
      block,
      workoutTemplate,
      arc,
      season,
    ]) {
      await db.delete(table).where(inArray(table.athleteId, athletes));
    }
    await db.delete(athlete).where(inArray(athlete.id, athletes));
  }
  await close();
});

const iso = (ms: number) => new Date(ms).toISOString();

/** A device-side snapshot: one athlete, plan and session, as the app sends it. */
function deviceRows(athleteId: string) {
  const t = Date.UTC(2026, 10, 2, 12);
  const base = { athlete_id: athleteId, created_at: iso(t), updated_at: iso(t), deleted_at: null };
  const ids = {
    season: uuidv7(),
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
    season: [{ ...base, id: ids.season, name: "Jiu-Jitsu", position: 0, active: true }],
    arc: [
      {
        ...base,
        id: ids.arc,
        season_id: ids.season,
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

const pushChanges = (token: string, changes: unknown) =>
  app.request("/v1/sync/push", {
    method: "POST",
    headers: headersFor(token),
    body: JSON.stringify({ changes }),
  });

const pullQuery = (athleteId: string, since?: string) =>
  `/v1/sync/pull?athleteId=${athleteId}${since ? `&since=${encodeURIComponent(since)}` : ""}`;

const pullSince = async (token: string, athleteId: string, since?: string) => {
  const res = await app.request(pullQuery(athleteId, since), { headers: headersFor(token) });
  expect(res.status).toBe(200);
  return (await res.json()) as {
    cursor: string | null;
    changes: Record<string, Record<string, unknown>[]>;
  };
};

describe("sync", () => {
  it("pushes a whole device snapshot and pulls it back in the same format", async () => {
    const leo = await signedIn();
    const { ids, changes } = deviceRows(leo.athleteId);
    const res = await pushChanges(leo.token, changes);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ applied: 9 });

    const pulled = await pullSince(leo.token, leo.athleteId);
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
    const leo = await signedIn();
    const { changes, t } = deviceRows(leo.athleteId);
    await pushChanges(leo.token, changes);
    const newer = { ...changes.athlete[0], display_name: "Leo Novo", updated_at: iso(t + 10_000) };
    await pushChanges(leo.token, { athlete: [newer] });
    const older = { ...changes.athlete[0], display_name: "Leo Velho", updated_at: iso(t + 5_000) };
    await pushChanges(leo.token, { athlete: [older] });
    const [stored] = await db.select().from(athlete).where(eq(athlete.id, leo.athleteId));
    expect(stored?.displayName).toBe("Leo Novo");
  });

  it("pulls only rows written after the cursor", async () => {
    const leo = await signedIn();
    const first = deviceRows(leo.athleteId);
    await pushChanges(leo.token, first.changes);
    const { cursor } = await pullSince(leo.token, leo.athleteId);
    expect((await pullSince(leo.token, leo.athleteId, cursor ?? undefined)).changes).toEqual({});

    const renamed = {
      ...first.changes.athlete[0],
      display_name: "Leo 2",
      updated_at: iso(first.t + 60_000),
    };
    await pushChanges(leo.token, { athlete: [renamed] });
    const after = await pullSince(leo.token, leo.athleteId, cursor ?? undefined);
    expect(after.changes.athlete?.map((row) => row.display_name)).toEqual(["Leo 2"]);
    expect(Object.keys(after.changes)).toEqual(["athlete"]);
  });

  it("refuses rows of another athlete", async () => {
    const leo = await signedIn();
    const other = await signedIn();
    const theirs = deviceRows(other.athleteId);
    const res = await pushChanges(leo.token, { season: theirs.changes.season });
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: "forbidden" });
    const stored = await db.select().from(season).where(eq(season.id, theirs.ids.season));
    expect(stored).toEqual([]);
    expect((await pushChanges(leo.token, { athlete: theirs.changes.athlete })).status).toBe(403);
  });

  it("cannot take over a row of another athlete by id", async () => {
    const leo = await signedIn();
    const other = await signedIn();
    const theirs = deviceRows(other.athleteId);
    await pushChanges(other.token, { season: theirs.changes.season });
    const hijack = {
      ...theirs.changes.season[0],
      athlete_id: leo.athleteId,
      name: "Roubada",
      updated_at: iso(theirs.t + 60_000),
    };
    const res = await pushChanges(leo.token, { season: [hijack] });
    expect([200, 403]).toContain(res.status);
    if (res.status === 200) expect(await res.json()).toEqual({ applied: 0 });
    const [stored] = await db.select().from(season).where(eq(season.id, theirs.ids.season));
    expect(stored?.athleteId).toBe(other.athleteId);
    expect(stored?.name).not.toBe("Roubada");
  });

  it("refuses rows that point to a parent of another athlete", async () => {
    const leo = await signedIn();
    const other = await signedIn();
    const theirs = deviceRows(other.athleteId);
    await pushChanges(other.token, theirs.changes);
    const mine = deviceRows(leo.athleteId);
    await pushChanges(leo.token, mine.changes);

    const intruder = {
      ...mine.changes.logged_set[0],
      id: uuidv7(),
      session_id: theirs.ids.session,
    };
    const res = await pushChanges(leo.token, { logged_set: [intruder] });
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: "forbidden" });
    expect(await db.select().from(loggedSet).where(eq(loggedSet.id, intruder.id))).toEqual([]);

    // A parent that exists only in the same push, or nowhere yet, is not someone else's.
    const newcomer = await signedIn();
    const fresh = deviceRows(newcomer.athleteId);
    expect((await pushChanges(newcomer.token, fresh.changes)).status).toBe(200);
  });

  it("pulls imported activities and refuses them for another athlete", async () => {
    const leo = await signedIn();
    const other = await signedIn();
    const id = uuidv7();
    await db.insert(importedActivity).values({
      id,
      athleteId: leo.athleteId,
      source: "garmin",
      externalId: `run-${id}`,
      activityType: "RUNNING",
      name: "Corrida",
      startedAt: new Date(Date.UTC(2026, 10, 3, 7)),
      durationSeconds: 2400,
      distanceMeters: "8200",
      averageHeartRate: 152,
      calories: 520,
    });
    const pulled = await pullSince(leo.token, leo.athleteId);
    const row = pulled.changes.imported_activity?.find((r) => r.id === id);
    expect(row).toMatchObject({
      distance_meters: "8200.00",
      duration_seconds: 2400,
      source: "garmin",
    });
    expect((await pushChanges(other.token, { imported_activity: [row] })).status).toBe(403);
  });

  it("pull only serves the session athlete", async () => {
    const leo = await signedIn();
    const other = await signedIn();
    await pushChanges(other.token, deviceRows(other.athleteId).changes);
    const res = await app.request(pullQuery(other.athleteId), { headers: headersFor(leo.token) });
    expect(res.status).toBe(403);
  });

  it("rejects unknown tables and requests without a session", async () => {
    const leo = await signedIn();
    expect((await pushChanges(leo.token, { nope: [] })).status).toBe(400);
    expect((await app.request("/v1/sync/pull")).status).toBe(401);
    expect((await app.request("/v1/sync/pull", { headers: headersFor(leo.token) })).status).toBe(
      400,
    );
  });
});
