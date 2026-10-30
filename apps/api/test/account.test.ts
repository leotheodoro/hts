import { eq, inArray } from "drizzle-orm";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete } from "../src/db/schema.js";
import { bearer, createTestAccount, createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const app = createApp({ db });
const athletes: string[] = [];

afterAll(async () => {
  await removeAccounts(db, athletes);
  if (athletes.length > 0) await db.delete(athlete).where(inArray(athlete.id, athletes));
  await close();
});

async function account() {
  const created = await createTestAccount(db);
  athletes.push(created.athleteId);
  return created;
}

const json = (token: string) => ({ ...bearer(token), "content-type": "application/json" });
const patch = (token: string, body: unknown) =>
  app.request("/v1/account", { method: "PATCH", headers: json(token), body: JSON.stringify(body) });
const changePassword = (token: string, currentPassword: string, newPassword: string) =>
  app.request("/v1/account/password", {
    method: "POST",
    headers: json(token),
    body: JSON.stringify({ currentPassword, newPassword }),
  });
const login = (identifier: string, password: string) =>
  app.request("/v1/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ identifier, password }),
  });

describe("PATCH /v1/account", () => {
  it("changes name, username and e-mail, and the name reaches the next pull", async () => {
    const leo = await account();
    const { cursor } = (await (
      await app.request(`/v1/sync/pull?athleteId=${leo.athleteId}`, { headers: bearer(leo.token) })
    ).json()) as { cursor: string };
    const res = await patch(leo.token, {
      name: "Leo Novo",
      username: `${leo.username}-x`,
      email: `x-${leo.email}`,
    });
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({
      athleteId: leo.athleteId,
      account: { name: "Leo Novo", username: `${leo.username}-x`, email: `x-${leo.email}` },
    });
    expect((await login(`${leo.username}-x`, leo.password)).status).toBe(200);
    const after = (await (
      await app.request(
        `/v1/sync/pull?athleteId=${leo.athleteId}&since=${encodeURIComponent(cursor)}`,
        { headers: bearer(leo.token) },
      )
    ).json()) as { changes: Record<string, Record<string, unknown>[]> };
    expect(after.changes.athlete?.map((row) => row.display_name)).toEqual(["Leo Novo"]);
  });

  it("keeps username and e-mail unique, ignoring case", async () => {
    const leo = await account();
    const other = await account();
    const taken = await patch(leo.token, { username: other.username.toUpperCase() });
    expect(taken.status).toBe(409);
    expect(await taken.json()).toEqual({ error: "username_taken" });
    const email = await patch(leo.token, { email: other.email.toUpperCase() });
    expect(email.status).toBe(409);
    expect(await email.json()).toEqual({ error: "email_taken" });
    expect((await patch(leo.token, { username: leo.username.toUpperCase() })).status).toBe(200);
  });

  it("rejects an invalid username or e-mail", async () => {
    const leo = await account();
    expect((await patch(leo.token, { username: "a b" })).status).toBe(400);
    expect((await patch(leo.token, { email: "not-an-email" })).status).toBe(400);
    expect((await patch(leo.token, { name: "  " })).status).toBe(400);
  });
});

describe("POST /v1/account/password", () => {
  it("needs the current password", async () => {
    const leo = await account();
    const wrong = await changePassword(leo.token, "wrong", "new-password-123");
    expect(wrong.status).toBe(401);
    expect(await wrong.json()).toEqual({ error: "invalid_credentials" });
    expect((await changePassword(leo.token, leo.password, "short")).status).toBe(400);
  });

  it("changes it and signs out the other devices, keeping this one", async () => {
    const leo = await account();
    const other = (await (await login(leo.username, leo.password)).json()) as { token: string };
    expect((await changePassword(leo.token, leo.password, "new-password-123")).status).toBe(204);
    expect((await login(leo.username, leo.password)).status).toBe(401);
    expect((await login(leo.username, "new-password-123")).status).toBe(200);
    expect((await app.request("/v1/auth/me", { headers: bearer(leo.token) })).status).toBe(200);
    expect((await app.request("/v1/auth/me", { headers: bearer(other.token) })).status).toBe(401);
    const [row] = await db.select().from(athlete).where(eq(athlete.id, leo.athleteId));
    expect(row).toBeDefined();
  });
});
