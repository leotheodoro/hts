import { inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete } from "../src/db/schema.js";
import { createTestDb } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
const created: string[] = [];

afterAll(async () => {
  if (created.length > 0) await db.delete(athlete).where(inArray(athlete.id, created));
  await close();
});

async function insertAthlete(values: Partial<typeof athlete.$inferInsert> = {}) {
  const id = uuidv7();
  created.push(id);
  const [row] = await db
    .insert(athlete)
    .values({ id, displayName: "Leo", ...values })
    .returning();
  if (!row) throw new Error("insert failed");
  return row;
}

describe("GET /v1/athletes/:id", () => {
  it("returns the athlete with the default rest of 90 s", async () => {
    const row = await insertAthlete();
    const res = await app.request(`/v1/athletes/${row.id}`);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      id: row.id,
      displayName: "Leo",
      defaultRestSeconds: 90,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    });
  });

  it("returns 404 for a soft-deleted athlete", async () => {
    const row = await insertAthlete({ deletedAt: new Date() });
    const res = await app.request(`/v1/athletes/${row.id}`);
    expect(res.status).toBe(404);
  });

  it("returns 404 for an unknown id", async () => {
    const res = await app.request(`/v1/athletes/${uuidv7()}`);
    expect(res.status).toBe(404);
  });

  it("rejects an id that is not a UUID", async () => {
    const res = await app.request("/v1/athletes/not-a-uuid");
    expect(res.status).toBe(400);
  });
});
