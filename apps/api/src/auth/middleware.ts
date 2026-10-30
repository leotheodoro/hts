import type { MiddlewareHandler } from "hono";
import type { Db } from "../db/client.js";
import { type AuthContext, resolveSession } from "./session.js";

export type AppEnv = { Variables: { auth: AuthContext } };

/** Paths under /v1 that need no session. */
const PUBLIC_PATHS = new Set(["/v1/auth/login"]);

/**
 * Requires `Authorization: Bearer <session token>` (docs/decisions/0031) and puts the account and
 * its athlete in the context as `auth`.
 */
export function sessionAuth(db: Db): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (PUBLIC_PATHS.has(c.req.path)) return next();
    const header = c.req.header("authorization") ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
    const auth = token ? await resolveSession(db, token) : null;
    if (!auth) return c.json({ error: "unauthorized" }, 401);
    c.set("auth", auth);
    await next();
  };
}
