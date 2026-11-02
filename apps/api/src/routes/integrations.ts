import { randomBytes, timingSafeEqual } from "node:crypto";
import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { and, eq, or } from "drizzle-orm";
import { bodyLimit } from "hono/body-limit";
import { v7 as uuidv7 } from "uuid";
import type { AppEnv } from "../auth/middleware.js";
import type { Db } from "../db/client.js";
import { integrationConnection, oauthState } from "../db/schema.js";
import { importGarminActivities, removeGarminUsers } from "../garmin/import.js";
import {
  authorizeUrl,
  codeVerifier,
  deleteRegistration,
  exchangeCode,
  fetchUserId,
  type GarminOAuthConfig,
  refreshTokens,
} from "../garmin/oauth.js";
import { parseGarminActivities, parseGarminDeregistrations } from "../garmin/payload.js";
import { error } from "./auth.js";

// Integrations page of the app, the Garmin login (OAuth2 PKCE, #168) and the Garmin push (spec 2026-10-31).
// Without the client id, secret and redirect URL, connect answers 503.

export interface GarminConfig {
  /** Secret path segment of the push URL registered at Garmin. Without it, the push route answers 404. */
  pushSecret?: string | undefined;
  clientId?: string | undefined;
  clientSecret?: string | undefined;
  redirectUri?: string | undefined;
  fetch?: typeof globalThis.fetch | undefined;
}

/** Where the callback sends the app back (ASWebAuthenticationSession listens for this scheme). */
const APP_CALLBACK = "hardtosubmit://integrations/garmin";
const STATE_TTL_MS = 10 * 60_000;
/** Far above a real push (a few summaries of a few hundred bytes each). */
const PUSH_MAX_BYTES = 5 * 1024 * 1024;

/** Compares the push secret in constant time, so its length and prefix do not leak through timing. */
function sameSecret(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

const oauthConfig = (garmin: GarminConfig): GarminOAuthConfig | null =>
  garmin.clientId && garmin.clientSecret && garmin.redirectUri
    ? {
        clientId: garmin.clientId,
        clientSecret: garmin.clientSecret,
        redirectUri: garmin.redirectUri,
        fetch: garmin.fetch,
      }
    : null;

const IntegrationSchema = z
  .object({
    provider: z.enum(["garmin"]),
    connected: z.boolean(),
    connectedAt: z.string().nullable(),
    lastActivityAt: z.string().nullable(),
  })
  .openapi("Integration");

const statusRoute = createRoute({
  method: "get",
  path: "/v1/integrations",
  operationId: "listIntegrations",
  tags: ["integrations"],
  summary: "Which platforms the session's account is connected to",
  security: [{ bearer: [] }],
  responses: {
    200: {
      description: "One entry per platform",
      content: {
        "application/json": { schema: z.object({ integrations: z.array(IntegrationSchema) }) },
      },
    },
    401: error("Missing, unknown or revoked session"),
  },
});

const connectRoute = createRoute({
  method: "post",
  path: "/v1/integrations/garmin/connect",
  operationId: "connectGarmin",
  tags: ["integrations"],
  summary: "Start the Garmin login; answers the page to open",
  security: [{ bearer: [] }],
  responses: {
    200: {
      description: "Garmin authorization page",
      content: { "application/json": { schema: z.object({ url: z.string() }) } },
    },
    401: error("Missing, unknown or revoked session"),
    503: error("garmin_unavailable: the Garmin client is not configured on the server"),
  },
});

const disconnectRoute = createRoute({
  method: "delete",
  path: "/v1/integrations/garmin",
  operationId: "disconnectGarmin",
  tags: ["integrations"],
  summary: "Forget the Garmin connection and its tokens; imported activities stay",
  security: [{ bearer: [] }],
  responses: {
    204: { description: "Disconnected" },
    401: error("Missing, unknown or revoked session"),
  },
});

export function integrationRoutes(db: Db, garmin: GarminConfig = {}) {
  const routes = new OpenAPIHono<AppEnv>()
    .openapi(statusRoute, async (c) => {
      const [connection] = await db
        .select()
        .from(integrationConnection)
        .where(
          and(
            eq(integrationConnection.accountId, c.get("auth").account.id),
            eq(integrationConnection.provider, "garmin"),
          ),
        );
      return c.json(
        {
          integrations: [
            {
              provider: "garmin" as const,
              connected: connection !== undefined,
              connectedAt: connection?.connectedAt.toISOString() ?? null,
              lastActivityAt: connection?.lastActivityAt?.toISOString() ?? null,
            },
          ],
        },
        200,
      );
    })
    .openapi(connectRoute, async (c) => {
      const config = oauthConfig(garmin);
      if (!config) return c.json({ error: "garmin_unavailable" }, 503);
      const accountId = c.get("auth").account.id;
      const state = randomBytes(32).toString("base64url");
      const verifier = codeVerifier();
      // One login in progress per account: an abandoned one is replaced.
      await db
        .delete(oauthState)
        .where(and(eq(oauthState.accountId, accountId), eq(oauthState.provider, "garmin")));
      await db
        .insert(oauthState)
        .values({ state, accountId, provider: "garmin", codeVerifier: verifier });
      return c.json({ url: authorizeUrl(config, state, verifier) }, 200);
    })
    .openapi(disconnectRoute, async (c) => {
      const accountId = c.get("auth").account.id;
      const where = and(
        eq(integrationConnection.accountId, accountId),
        eq(integrationConnection.provider, "garmin"),
      );
      const [connection] = await db.select().from(integrationConnection).where(where);
      const config = oauthConfig(garmin);
      // Garmin requires removing the registration when the app offers "Desconectar". Best effort: the
      // connection goes away here even if Garmin does not answer, and its deregistration push ends it there.
      if (connection?.accessToken && config) {
        try {
          const expired = !connection.tokenExpiresAt || connection.tokenExpiresAt <= new Date();
          const token =
            expired && connection.refreshToken
              ? (await refreshTokens(config, connection.refreshToken)).accessToken
              : connection.accessToken;
          await deleteRegistration(config, token);
        } catch (failure) {
          console.error("garmin deregistration failed", failure);
        }
      }
      await db.delete(integrationConnection).where(where);
      return c.body(null, 204);
    });
  // Outside /v1: Garmin sends the browser here after the login, without a session. The state ties it to the
  // account that pressed "Conectar"; the app gets back `?status=connected|denied|error`.
  routes.get("/integrations/garmin/callback", async (c) => {
    const back = (status: string) => c.redirect(`${APP_CALLBACK}?status=${status}`, 302);
    const config = oauthConfig(garmin);
    const state = c.req.query("state");
    if (!config || !state) return back("error");
    const [pending] = await db.delete(oauthState).where(eq(oauthState.state, state)).returning();
    if (!pending || Date.now() - pending.createdAt.getTime() > STATE_TTL_MS) return back("error");
    if (c.req.query("error")) return back("denied");
    const code = c.req.query("code");
    if (!code) return back("error");
    try {
      const tokens = await exchangeCode(config, code, pending.codeVerifier);
      const userId = await fetchUserId(config, tokens.accessToken);
      await db.transaction(async (tx) => {
        // The Garmin user moves to this account, and the account keeps one Garmin user.
        await tx
          .delete(integrationConnection)
          .where(
            and(
              eq(integrationConnection.provider, "garmin"),
              or(
                eq(integrationConnection.accountId, pending.accountId),
                eq(integrationConnection.externalUserId, userId),
              ),
            ),
          );
        await tx.insert(integrationConnection).values({
          id: uuidv7(),
          accountId: pending.accountId,
          provider: "garmin",
          externalUserId: userId,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          tokenExpiresAt: tokens.expiresAt,
        });
      });
      return back("connected");
    } catch (failure) {
      console.error("garmin login failed", failure);
      return back("error");
    }
  });
  // Outside /v1: Garmin calls it without a session, so the secret path segment is what lets it in. Not in
  // the OpenAPI document, since the app never calls it.
  routes.post(
    "/integrations/garmin/push/:secret",
    bodyLimit({ maxSize: PUSH_MAX_BYTES, onError: (c) => c.json({ error: "too_large" }, 413) }),
    async (c) => {
      if (!garmin.pushSecret || !sameSecret(c.req.param("secret"), garmin.pushSecret))
        return c.notFound();
      const body = await c.req.json().catch(() => null);
      await removeGarminUsers(db, parseGarminDeregistrations(body));
      return c.json(await importGarminActivities(db, parseGarminActivities(body)), 200);
    },
  );
  return routes;
}
