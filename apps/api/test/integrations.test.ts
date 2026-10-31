import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete, importedActivity, integrationConnection } from "../src/db/schema.js";
import { bearer, createTestAccount, createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
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

async function signedIn() {
  const leo = await createTestAccount(db);
  athletes.push(leo.athleteId);
  accounts.push(leo.accountId);
  return leo;
}

const connectedAt = new Date(Date.UTC(2026, 10, 1, 12));
const lastActivityAt = new Date(Date.UTC(2026, 10, 2, 10, 20));

async function connect(accountId: string) {
  await db.insert(integrationConnection).values({
    id: uuidv7(),
    accountId,
    provider: "garmin",
    externalUserId: `garmin-${uuidv7()}`,
    connectedAt,
    lastActivityAt,
  });
}

describe("integrations", () => {
  it("status shows connected and the last activity", async () => {
    const leo = await signedIn();
    const before = await app.request("/v1/integrations", { headers: bearer(leo.token) });
    expect(await before.json()).toEqual({
      integrations: [
        { provider: "garmin", connected: false, connectedAt: null, lastActivityAt: null },
      ],
    });
    await connect(leo.accountId);
    const after = await app.request("/v1/integrations", { headers: bearer(leo.token) });
    expect(after.status).toBe(200);
    expect(await after.json()).toEqual({
      integrations: [
        {
          provider: "garmin",
          connected: true,
          connectedAt: connectedAt.toISOString(),
          lastActivityAt: lastActivityAt.toISOString(),
        },
      ],
    });
  });

  it("disconnect removes the connection and keeps the activities", async () => {
    const leo = await signedIn();
    await connect(leo.accountId);
    const id = uuidv7();
    await db.insert(importedActivity).values({
      id,
      athleteId: leo.athleteId,
      source: "garmin",
      externalId: `s-${id}`,
      activityType: "RUNNING",
      startedAt: lastActivityAt,
      durationSeconds: 2400,
    });
    const res = await app.request("/v1/integrations/garmin", {
      method: "DELETE",
      headers: bearer(leo.token),
    });
    expect(res.status).toBe(204);
    const left = await db
      .select()
      .from(integrationConnection)
      .where(eq(integrationConnection.accountId, leo.accountId));
    expect(left).toEqual([]);
    const kept = await db.select().from(importedActivity).where(eq(importedActivity.id, id));
    expect(kept).toHaveLength(1);
  });

  it("connect answers 503 until Garmin is configured", async () => {
    const leo = await signedIn();
    const res = await app.request("/v1/integrations/garmin/connect", {
      method: "POST",
      headers: bearer(leo.token),
    });
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "garmin_unavailable" });
  });

  it("routes need a session", async () => {
    expect((await app.request("/v1/integrations")).status).toBe(401);
    expect((await app.request("/v1/integrations/garmin", { method: "DELETE" })).status).toBe(401);
  });
});
