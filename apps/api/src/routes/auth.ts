import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { and, eq, isNull, or, sql } from "drizzle-orm";
import { clientIp } from "../auth/client-ip.js";
import type { AppEnv } from "../auth/middleware.js";
import { verifyPassword } from "../auth/password.js";
import { ConcurrencyLimit, type LoginLimiter } from "../auth/rate-limit.js";
import { type AccountRow, createSession, revokeSession } from "../auth/session.js";
import type { Db } from "../db/client.js";
import { account } from "../db/schema.js";

const AccountSchema = z
  .object({
    id: z.uuid(),
    name: z.string().openapi({ example: "Leonardo Theodoro" }),
    username: z.string().openapi({ example: "leotheodoro" }),
    email: z.string(),
    avatarUrl: z.string().nullable(),
  })
  .openapi("Account");

const SessionSchema = z
  .object({ token: z.string(), athleteId: z.uuid(), account: AccountSchema })
  .openapi("AuthSession");

const MeSchema = z.object({ athleteId: z.uuid(), account: AccountSchema }).openapi("Me");

const ErrorSchema = z.object({ error: z.string() }).openapi("Error");
const error = (description: string) => ({
  description,
  content: { "application/json": { schema: ErrorSchema } },
});

const loginRoute = createRoute({
  method: "post",
  path: "/v1/auth/login",
  operationId: "login",
  tags: ["auth"],
  summary: "Log in with username or e-mail and password",
  request: {
    body: {
      content: {
        "application/json": {
          schema: z.object({
            identifier: z.string().min(1).max(320),
            password: z.string().min(1).max(1024),
          }),
        },
      },
    },
  },
  responses: {
    200: {
      description: "Logged in: a session token that lasts until logout",
      content: { "application/json": { schema: SessionSchema } },
    },
    401: error("Unknown user or wrong password (same answer for both)"),
    429: error("Too many failed attempts"),
  },
});

const meRoute = createRoute({
  method: "get",
  path: "/v1/auth/me",
  operationId: "me",
  tags: ["auth"],
  summary: "The account of the current session",
  security: [{ bearer: [] }],
  responses: {
    200: { description: "Current account", content: { "application/json": { schema: MeSchema } } },
    401: error("Missing, unknown or revoked session"),
  },
});

const logoutRoute = createRoute({
  method: "post",
  path: "/v1/auth/logout",
  operationId: "logout",
  tags: ["auth"],
  summary: "Revoke the current session",
  security: [{ bearer: [] }],
  responses: {
    204: { description: "Session revoked" },
    401: error("Missing, unknown or revoked session"),
  },
});

const toAccount = (row: AccountRow) => ({
  id: row.id,
  name: row.name,
  username: row.username,
  email: row.email,
  avatarUrl: row.avatarUrl,
});

export function authRoutes(db: Db, limiter: LoginLimiter) {
  // Each argon2 check takes ~19 MiB: a few at a time keep a flood from exhausting the instance.
  const checks = new ConcurrencyLimit(4);
  return new OpenAPIHono<AppEnv>()
    .openapi(loginRoute, async (c) => {
      const { identifier, password } = c.req.valid("json");
      const id = identifier.trim().toLowerCase();
      const ip = clientIp((name) => c.req.header(name));
      const keys = [`ip:${ip}`, `id:${id}`];
      if (limiter.isBlocked(keys)) return c.json({ error: "too_many_attempts" }, 429);

      const [row] = await db
        .select()
        .from(account)
        .where(
          and(
            isNull(account.deletedAt),
            or(eq(sql`lower(${account.username})`, id), eq(sql`lower(${account.email})`, id)),
          ),
        )
        .limit(1);
      const valid = await checks.run(() => verifyPassword(row?.passwordHash ?? null, password));
      if (!row || !valid) {
        limiter.recordFailure(keys);
        return c.json({ error: "invalid_credentials" }, 401);
      }
      limiter.reset(`id:${id}`);
      const token = await createSession(db, row.id);
      return c.json({ token, athleteId: row.athleteId, account: toAccount(row) }, 200);
    })
    .openapi(meRoute, (c) => {
      const auth = c.get("auth");
      return c.json({ athleteId: auth.athleteId, account: toAccount(auth.account) }, 200);
    })
    .openapi(logoutRoute, async (c) => {
      await revokeSession(db, c.get("auth").sessionId);
      return c.body(null, 204);
    });
}
