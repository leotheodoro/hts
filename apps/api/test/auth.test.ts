import { eq, inArray } from "drizzle-orm";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { clientIp } from "../src/auth/client-ip.js";
import { ConcurrencyLimit, LoginLimiter } from "../src/auth/rate-limit.js";
import { athlete, authSession } from "../src/db/schema.js";
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

const login = (identifier: string, password: string, target = app, ip = "10.0.0.1") =>
  target.request("/v1/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": ip },
    body: JSON.stringify({ identifier, password }),
  });

describe("POST /v1/auth/login", () => {
  it("logs in by username and by e-mail, ignoring case and spaces", async () => {
    const leo = await account();
    for (const identifier of [leo.username, `  ${leo.email.toUpperCase()} `]) {
      const res = await login(identifier, leo.password);
      expect(res.status).toBe(200);
      const body = (await res.json()) as {
        token: string;
        athleteId: string;
        account: { username: string; email: string; name: string; avatarUrl: string | null };
      };
      expect(body.token).toHaveLength(43);
      expect(body.athleteId).toBe(leo.athleteId);
      expect(body.account).toMatchObject({
        username: leo.username,
        email: leo.email,
        name: "Leo",
        avatarUrl: null,
      });
    }
  });

  it("answers the same 401 for an unknown user and a wrong password", async () => {
    const leo = await account();
    const unknown = await login("nobody-here", leo.password);
    const wrong = await login(leo.username, "wrong-password");
    expect(unknown.status).toBe(401);
    expect(wrong.status).toBe(401);
    expect(await unknown.json()).toEqual({ error: "invalid_credentials" });
    expect(await wrong.json()).toEqual({ error: "invalid_credentials" });
  });

  it("limits login attempts", async () => {
    const leo = await account();
    const limited = createApp({ db });
    for (let i = 0; i < 10; i++) {
      expect((await login(leo.username, "wrong", limited, `10.1.0.${i}`)).status).toBe(401);
    }
    const blocked = await login(leo.username, leo.password, limited, "10.1.0.99");
    expect(blocked.status).toBe(429);
    expect(await blocked.json()).toEqual({ error: "too_many_attempts" });
  });

  it("stores only the token hash", async () => {
    const leo = await account();
    const { token } = (await (await login(leo.username, leo.password)).json()) as {
      token: string;
    };
    const rows = await db.select().from(authSession);
    expect(rows.some((r) => r.tokenHash === token)).toBe(false);
    expect(rows.every((r) => /^[0-9a-f]{64}$/.test(r.tokenHash))).toBe(true);
  });
});

describe("sessions", () => {
  it("rejects /v1 without a session and accepts a live one", async () => {
    const leo = await account();
    expect((await app.request("/v1/auth/me")).status).toBe(401);
    expect((await app.request("/v1/auth/me", { headers: bearer("nope") })).status).toBe(401);
    const res = await app.request("/v1/auth/me", { headers: bearer(leo.token) });
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({
      athleteId: leo.athleteId,
      account: { username: leo.username },
    });
  });

  it("logout revokes only that session", async () => {
    const leo = await account();
    const second = (await (await login(leo.username, leo.password)).json()) as { token: string };
    const out = await app.request("/v1/auth/logout", {
      method: "POST",
      headers: bearer(leo.token),
    });
    expect(out.status).toBe(204);
    expect((await app.request("/v1/auth/me", { headers: bearer(leo.token) })).status).toBe(401);
    expect((await app.request("/v1/auth/me", { headers: bearer(second.token) })).status).toBe(200);
    const [revoked] = await db
      .select()
      .from(authSession)
      .where(eq(authSession.accountId, leo.accountId));
    expect(revoked).toBeDefined();
  });

  it("keeps /health public", async () => {
    expect((await app.request("/health")).status).toBe(200);
  });
});

describe("login hardening", () => {
  it("takes the client IP from a header the client cannot forge", () => {
    const headers = (values: Record<string, string>) => (name: string) => values[name];
    expect(clientIp(headers({ "cf-connecting-ip": "1.1.1.1", "x-forwarded-for": "6.6.6.6" }))).toBe(
      "1.1.1.1",
    );
    expect(clientIp(headers({ "x-forwarded-for": "6.6.6.6, 10.0.0.9" }))).toBe("10.0.0.9");
    expect(clientIp(headers({}))).toBe("local");
  });

  it("ignores a spoofed leftmost X-Forwarded-For", async () => {
    const limited = createApp({ db });
    for (let i = 0; i < 10; i++) {
      const res = await login(`nobody-${i}`, "wrong", limited, `spoof-${i}, 10.3.0.1`);
      expect(res.status).toBe(401);
    }
    expect((await login("nobody-else", "wrong", limited, "spoof-x, 10.3.0.1")).status).toBe(429);
  });

  it("forgets keys whose failures left the window", () => {
    let now = 0;
    const limiter = new LoginLimiter(10, 1000, () => now);
    for (let i = 0; i < 50; i++) limiter.recordFailure([`id:${i}`]);
    expect(limiter.size).toBe(50);
    now = 2000;
    limiter.recordFailure(["id:new"]);
    expect(limiter.size).toBe(1);
  });

  it("runs at most N password checks at once", async () => {
    const limit = new ConcurrencyLimit(2);
    let running = 0;
    let peak = 0;
    await Promise.all(
      Array.from({ length: 8 }, () =>
        limit.run(async () => {
          running++;
          peak = Math.max(peak, running);
          await new Promise((resolve) => setTimeout(resolve, 5));
          running--;
        }),
      ),
    );
    expect(peak).toBe(2);
  });

  it("rejects an oversized password before hashing it", async () => {
    expect((await login("leo", "x".repeat(2000))).status).toBe(400);
  });
});
