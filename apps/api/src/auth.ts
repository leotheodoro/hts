import { timingSafeEqual } from "node:crypto";
import type { MiddlewareHandler } from "hono";

/**
 * Requires `Authorization: Bearer <API_TOKEN>` (docs/decisions/0024). Compared in constant time.
 * Replaced by real accounts if the app opens to other athletes.
 */
export function bearerAuth(token: string): MiddlewareHandler {
  const expected = Buffer.from(token);
  return async (c, next) => {
    const header = c.req.header("authorization") ?? "";
    const given = Buffer.from(header.startsWith("Bearer ") ? header.slice(7) : "");
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
      return c.json({ error: "unauthorized" }, 401);
    }
    await next();
  };
}
