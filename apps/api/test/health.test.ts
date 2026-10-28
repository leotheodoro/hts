import { describe, expect, it } from "vitest";
import pkg from "../package.json" with { type: "json" };
import { createApp } from "../src/app.js";

describe("GET /health", () => {
  it("reports status and version", async () => {
    const res = await createApp().request("/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok", version: pkg.version });
  });
});
