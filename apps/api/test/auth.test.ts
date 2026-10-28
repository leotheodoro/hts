import { describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { loadEnv } from "../src/env.js";
import { createTestDb, testApiToken } from "./db.js";

const { db } = createTestDb();
const app = createApp({ db, apiToken: testApiToken });
const path = "/v1/athletes/0190f2c4-0000-7000-8000-000000000000";

describe("bearer token", () => {
  it("rejects /v1 without a token or with a wrong one", async () => {
    expect((await app.request(path)).status).toBe(401);
    const wrong = await app.request(path, { headers: { authorization: "Bearer nope" } });
    expect(wrong.status).toBe(401);
  });

  it("accepts the right token", async () => {
    const res = await app.request(path, { headers: { authorization: `Bearer ${testApiToken}` } });
    expect(res.status).toBe(404);
  });

  it("keeps /health public", async () => {
    expect((await app.request("/health")).status).toBe(200);
  });

  it("requires a long API_TOKEN", () => {
    expect(() =>
      loadEnv({
        DATABASE_URL: "postgres://x@localhost/x",
        API_TOKEN: "short",
      } as NodeJS.ProcessEnv),
    ).toThrow(/API_TOKEN/);
  });
});
