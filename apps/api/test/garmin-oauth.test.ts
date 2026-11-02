import { createHash } from "node:crypto";
import { eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete, integrationConnection, oauthState } from "../src/db/schema.js";
import { bearer, createTestAccount, createTestDb, removeAccounts } from "./db.js";

const { db, close } = createTestDb();
const athletes: string[] = [];
const accounts: string[] = [];

afterAll(async () => {
  if (accounts.length > 0) {
    await db.delete(oauthState).where(inArray(oauthState.accountId, accounts));
    await db
      .delete(integrationConnection)
      .where(inArray(integrationConnection.accountId, accounts));
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

type Call = { url: string; method: string; headers: Headers; body: string };

/** Plays Garmin: the token endpoint, the user id and the registration, recording every call. */
function fakeGarmin(userId = `g-${uuidv7()}`) {
  const calls: Call[] = [];
  let tokens = 0;
  const fetch = async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    const call = {
      url,
      method: init?.method ?? "GET",
      headers: new Headers(init?.headers),
      body: String(init?.body ?? ""),
    };
    calls.push(call);
    if (url === "https://diauth.garmin.com/di-oauth2-service/oauth/token") {
      tokens += 1;
      return Response.json({
        access_token: `access-${tokens}`,
        refresh_token: `refresh-${tokens}`,
        expires_in: 86400,
        refresh_token_expires_in: 7775998,
        token_type: "bearer",
      });
    }
    if (url === "https://apis.garmin.com/wellness-api/rest/user/id")
      return Response.json({ userId });
    if (url === "https://apis.garmin.com/wellness-api/rest/user/registration") {
      return new Response(null, { status: 204 });
    }
    return new Response("not found", { status: 404 });
  };
  return { fetch, calls, userId };
}

const config = (fetch: typeof globalThis.fetch) => ({
  clientId: "client-123",
  clientSecret: "secret-456",
  redirectUri: "https://api.hardtosubmit.com/integrations/garmin/callback",
  fetch,
});

const base64url = (buffer: Buffer) => buffer.toString("base64url");

async function connect(app: ReturnType<typeof createApp>, token: string) {
  const res = await app.request("/v1/integrations/garmin/connect", {
    method: "POST",
    headers: bearer(token),
  });
  expect(res.status).toBe(200);
  return new URL(((await res.json()) as { url: string }).url);
}

describe("Garmin login (OAuth2 PKCE)", () => {
  it("connect answers the Garmin authorization page with PKCE", async () => {
    const leo = await signedIn();
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    const url = await connect(app, leo.token);
    expect(`${url.origin}${url.pathname}`).toBe("https://connect.garmin.com/oauth2Confirm");
    expect(url.searchParams.get("client_id")).toBe("client-123");
    expect(url.searchParams.get("response_type")).toBe("code");
    expect(url.searchParams.get("code_challenge_method")).toBe("S256");
    expect(url.searchParams.get("redirect_uri")).toBe(
      "https://api.hardtosubmit.com/integrations/garmin/callback",
    );
    const state = url.searchParams.get("state") ?? "";
    const [saved] = await db.select().from(oauthState).where(eq(oauthState.state, state));
    expect(saved?.accountId).toBe(leo.accountId);
    expect(saved?.codeVerifier).toMatch(/^[A-Za-z0-9._~-]{43,128}$/);
    const challenge = base64url(
      createHash("sha256")
        .update(saved?.codeVerifier ?? "")
        .digest(),
    );
    expect(url.searchParams.get("code_challenge")).toBe(challenge);
  });

  it("the callback stores the connection and sends the app back", async () => {
    const leo = await signedIn();
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    const state = (await connect(app, leo.token)).searchParams.get("state") ?? "";
    const [saved] = await db.select().from(oauthState).where(eq(oauthState.state, state));

    const res = await app.request(`/integrations/garmin/callback?code=abc&state=${state}`);
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe("hardtosubmit://integrations/garmin?status=connected");

    const exchange = garmin.calls.find((c) => c.url.endsWith("/oauth/token"));
    const form = new URLSearchParams(exchange?.body);
    expect(exchange?.method).toBe("POST");
    expect(exchange?.headers.get("content-type")).toBe("application/x-www-form-urlencoded");
    expect(Object.fromEntries(form)).toEqual({
      grant_type: "authorization_code",
      client_id: "client-123",
      client_secret: "secret-456",
      code: "abc",
      code_verifier: saved?.codeVerifier,
      redirect_uri: "https://api.hardtosubmit.com/integrations/garmin/callback",
    });
    const userIdCall = garmin.calls.find((c) => c.url.endsWith("/user/id"));
    expect(userIdCall?.headers.get("authorization")).toBe("Bearer access-1");

    const [connection] = await db
      .select()
      .from(integrationConnection)
      .where(eq(integrationConnection.accountId, leo.accountId));
    expect(connection).toMatchObject({
      provider: "garmin",
      externalUserId: garmin.userId,
      accessToken: "access-1",
      refreshToken: "refresh-1",
    });
    // expires_in minus the 10 minute margin Garmin recommends.
    const lifetime = (connection?.tokenExpiresAt?.getTime() ?? 0) - Date.now();
    expect(lifetime).toBeGreaterThan(85_700_000);
    expect(lifetime).toBeLessThanOrEqual(85_800_000);
    expect(await db.select().from(oauthState).where(eq(oauthState.state, state))).toEqual([]);
  });

  it("a callback with an unknown state connects nothing", async () => {
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    const res = await app.request("/integrations/garmin/callback?code=abc&state=nope");
    expect(res.headers.get("location")).toBe("hardtosubmit://integrations/garmin?status=error");
    expect(garmin.calls).toEqual([]);
  });

  it("a declined login sends the app back without connecting", async () => {
    const leo = await signedIn();
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    const state = (await connect(app, leo.token)).searchParams.get("state") ?? "";
    const res = await app.request(
      `/integrations/garmin/callback?error=access_denied&state=${state}`,
    );
    expect(res.headers.get("location")).toBe("hardtosubmit://integrations/garmin?status=denied");
    const rows = await db
      .select()
      .from(integrationConnection)
      .where(eq(integrationConnection.accountId, leo.accountId));
    expect(rows).toEqual([]);
  });

  it("an expired state connects nothing", async () => {
    const leo = await signedIn();
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    const state = `old-${uuidv7()}`;
    await db.insert(oauthState).values({
      state,
      accountId: leo.accountId,
      provider: "garmin",
      codeVerifier: "v".repeat(64),
      createdAt: new Date(Date.now() - 11 * 60_000),
    });
    const res = await app.request(`/integrations/garmin/callback?code=abc&state=${state}`);
    expect(res.headers.get("location")).toBe("hardtosubmit://integrations/garmin?status=error");
    expect(garmin.calls).toEqual([]);
  });

  it("disconnect deletes the registration at Garmin, refreshing an expired token first", async () => {
    const leo = await signedIn();
    const garmin = fakeGarmin();
    const app = createApp({ db, garmin: config(garmin.fetch) });
    await db.insert(integrationConnection).values({
      id: uuidv7(),
      accountId: leo.accountId,
      provider: "garmin",
      externalUserId: garmin.userId,
      accessToken: "stale",
      refreshToken: "refresh-old",
      tokenExpiresAt: new Date(Date.now() - 1000),
    });
    const res = await app.request("/v1/integrations/garmin", {
      method: "DELETE",
      headers: bearer(leo.token),
    });
    expect(res.status).toBe(204);
    const refresh = new URLSearchParams(garmin.calls[0]?.body);
    expect(refresh.get("grant_type")).toBe("refresh_token");
    expect(refresh.get("refresh_token")).toBe("refresh-old");
    const deregister = garmin.calls[1];
    expect(deregister?.method).toBe("DELETE");
    expect(deregister?.url).toBe("https://apis.garmin.com/wellness-api/rest/user/registration");
    expect(deregister?.headers.get("authorization")).toBe("Bearer access-1");
    const rows = await db
      .select()
      .from(integrationConnection)
      .where(eq(integrationConnection.accountId, leo.accountId));
    expect(rows).toEqual([]);
  });
});
