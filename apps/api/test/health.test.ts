import { afterAll, describe, expect, it } from "vitest";
import pkg from "../package.json" with { type: "json" };
import { createApp } from "../src/app.js";
import { createTestDb, testApiToken } from "./db.js";

const { db, close } = createTestDb();
afterAll(close);

describe("GET /health", () => {
  it("reports status and version", async () => {
    const res = await createApp({ db, apiToken: testApiToken }).request("/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok", version: pkg.version });
  });
});
