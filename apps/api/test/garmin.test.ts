import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete, importedActivity, integrationConnection } from "../src/db/schema.js";
import { createTestAccount, createTestDb, removeAccounts } from "./db.js";
import payload from "./fixtures/garmin-activities.json" with { type: "json" };

const { db, close } = createTestDb();
const SECRET = "push-secret-test";
const app = createApp({ db, garmin: { pushSecret: SECRET } });
const athletes: string[] = [];
const accounts: string[] = [];

afterAll(async () => {
  if (accounts.length > 0) {
    await db
      .delete(integrationConnection)
      .where(inArray(integrationConnection.accountId, accounts));
  }
  if (athletes.length > 0) {
    await db.delete(importedActivity).where(inArray(importedActivity.athleteId, athletes));
  }
  await removeAccounts(db, athletes);
  if (athletes.length > 0) await db.delete(athlete).where(inArray(athlete.id, athletes));
  await close();
});

/** An account connected to Garmin as `garminUser`. */
async function connected() {
  const leo = await createTestAccount(db);
  athletes.push(leo.athleteId);
  accounts.push(leo.accountId);
  const garminUser = `garmin-${uuidv7()}`;
  await db.insert(integrationConnection).values({
    id: uuidv7(),
    accountId: leo.accountId,
    provider: "garmin",
    externalUserId: garminUser,
  });
  return { ...leo, garminUser };
}

/** The sample push with this user and summary id. */
function push(user: string, summaryId: string, changes: Record<string, unknown> = {}) {
  const [activity] = payload.activities;
  return { activities: [{ ...activity, userId: user, summaryId, ...changes }] };
}

const send = (body: unknown, secret = SECRET) =>
  app.request(`/integrations/garmin/push/${secret}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

const activitiesOf = (athleteId: string) =>
  db.select().from(importedActivity).where(eq(importedActivity.athleteId, athleteId));

describe("Garmin push", () => {
  it("imports an activity of a connected user", async () => {
    const leo = await connected();
    const res = await send(push(leo.garminUser, `s-${uuidv7()}`));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ imported: 1, ignored: 0 });
    const [row] = await activitiesOf(leo.athleteId);
    expect(row).toMatchObject({
      source: "garmin",
      activityType: "RUNNING",
      name: "Corrida",
      durationSeconds: 2400,
      distanceMeters: "8200.40",
      averageHeartRate: 152,
      calories: 520,
      deletedAt: null,
    });
    expect(row?.startedAt.toISOString()).toBe("2026-11-02T07:00:00.000Z");
    const [connection] = await db
      .select()
      .from(integrationConnection)
      .where(eq(integrationConnection.externalUserId, leo.garminUser));
    expect(connection?.lastActivityAt?.toISOString()).toBe("2026-11-02T07:00:00.000Z");
  });

  it("a repeated activity updates the same row", async () => {
    const leo = await connected();
    const summary = `s-${uuidv7()}`;
    await send(push(leo.garminUser, summary));
    const [first] = await activitiesOf(leo.athleteId);
    await send(push(leo.garminUser, summary, { durationInSeconds: 3000 }));
    const rows = await activitiesOf(leo.athleteId);
    expect(rows).toHaveLength(1);
    expect(rows[0]?.id).toBe(first?.id);
    expect(rows[0]?.durationSeconds).toBe(3000);
    expect(rows[0]?.serverUpdatedAt.getTime()).toBeGreaterThanOrEqual(
      first?.serverUpdatedAt.getTime() ?? 0,
    );
  });

  it("ignores activities of an unknown Garmin user", async () => {
    const res = await send(push(`nobody-${uuidv7()}`, `s-${uuidv7()}`));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ imported: 0, ignored: 1 });
  });

  it("a deletion soft-deletes", async () => {
    const leo = await connected();
    const summary = `s-${uuidv7()}`;
    await send(push(leo.garminUser, summary));
    await send(push(leo.garminUser, summary, { deleted: true }));
    const [row] = await activitiesOf(leo.athleteId);
    expect(row?.deletedAt).not.toBeNull();
  });

  it("wrong secret answers 404", async () => {
    expect((await send(push("x", "y"), "wrong")).status).toBe(404);
    const unconfigured = createApp({ db });
    const res = await unconfigured.request("/integrations/garmin/push/anything", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    });
    expect(res.status).toBe(404);
  });
});
