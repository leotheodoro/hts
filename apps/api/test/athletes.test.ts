import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete } from "../src/db/schema.js";
import { bearer, createTestAccount, createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
const created: string[] = [];

afterAll(async () => {
  await removeAccounts(db, created);
  if (created.length > 0) await db.delete(athlete).where(inArray(athlete.id, created));
  await close();
});

async function signedIn() {
  const leo = await createTestAccount(db);
  created.push(leo.athleteId);
  return { leo, auth: { headers: bearer(leo.token) } };
}

describe("GET /v1/athletes/:id", () => {
  it("returns the session athlete with the default rest of 90 s", async () => {
    const { leo, auth } = await signedIn();
    const res = await app.request(`/v1/athletes/${leo.athleteId}`, auth);
    expect(res.status).toBe(200);
    const [row] = await db.select().from(athlete).where(eq(athlete.id, leo.athleteId));
    expect(await res.json()).toEqual({
      id: leo.athleteId,
      displayName: "Leo",
      defaultRestSeconds: 90,
      createdAt: row?.createdAt.toISOString(),
      updatedAt: row?.updatedAt.toISOString(),
    });
  });

  it("refuses another athlete", async () => {
    const { auth } = await signedIn();
    const { leo: other } = await signedIn();
    expect((await app.request(`/v1/athletes/${other.athleteId}`, auth)).status).toBe(403);
    expect((await app.request(`/v1/athletes/${uuidv7()}`, auth)).status).toBe(403);
  });

  it("returns 404 when the session athlete was deleted", async () => {
    const { leo, auth } = await signedIn();
    await db.update(athlete).set({ deletedAt: new Date() }).where(eq(athlete.id, leo.athleteId));
    expect((await app.request(`/v1/athletes/${leo.athleteId}`, auth)).status).toBe(404);
  });

  it("rejects an id that is not a UUID", async () => {
    const { auth } = await signedIn();
    const res = await app.request("/v1/athletes/not-a-uuid", auth);
    expect(res.status).toBe(400);
  });
});
