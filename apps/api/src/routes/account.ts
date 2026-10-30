import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { and, eq, isNull, ne, sql } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { AppEnv } from "../auth/middleware.js";
import { hashPassword, verifyPassword } from "../auth/password.js";
import type { Db } from "../db/client.js";
import { account, athlete, authSession } from "../db/schema.js";
import type { AvatarStorage } from "../storage.js";
import { error, MeSchema, toAccount } from "./auth.js";

// The account edits itself ("Minha conta", #141). Username and e-mail stay unique ignoring case.

const UpdateSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  username: z
    .string()
    .trim()
    .regex(/^[A-Za-z0-9._-]{3,30}$/, "3 to 30 letters, digits, dot, dash or underscore")
    .optional(),
  email: z.email().trim().max(320).optional(),
});

const updateRoute = createRoute({
  method: "patch",
  path: "/v1/account",
  operationId: "updateAccount",
  tags: ["account"],
  summary: "Change the name, username or e-mail of the session's account",
  security: [{ bearer: [] }],
  request: { body: { content: { "application/json": { schema: UpdateSchema } } } },
  responses: {
    200: { description: "Updated account", content: { "application/json": { schema: MeSchema } } },
    401: error("Missing, unknown or revoked session"),
    409: error("username_taken or email_taken"),
  },
});

const passwordRoute = createRoute({
  method: "post",
  path: "/v1/account/password",
  operationId: "changePassword",
  tags: ["account"],
  summary: "Change the password; other devices are signed out",
  security: [{ bearer: [] }],
  request: {
    body: {
      content: {
        "application/json": {
          schema: z.object({
            currentPassword: z.string().min(1).max(1024),
            newPassword: z.string().min(8).max(1024),
          }),
        },
      },
    },
  },
  responses: {
    204: { description: "Password changed" },
    401: error("Wrong current password, or missing session"),
  },
});

const MAX_AVATAR_BYTES = 2 * 1024 * 1024;

const avatarRoute = createRoute({
  method: "put",
  path: "/v1/account/avatar",
  operationId: "uploadAvatar",
  tags: ["account"],
  summary: "Replace the account photo (JPEG up to 2 MB)",
  security: [{ bearer: [] }],
  request: {
    body: {
      content: {
        "image/jpeg": { schema: z.string().openapi({ type: "string", format: "binary" }) },
      },
    },
  },
  responses: {
    200: { description: "Updated account", content: { "application/json": { schema: MeSchema } } },
    400: error("Not a JPEG"),
    401: error("Missing, unknown or revoked session"),
    413: error("Larger than 2 MB"),
    503: error("Photo storage is not configured"),
  },
});

export function accountRoutes(db: Db, storage?: AvatarStorage) {
  return new OpenAPIHono<AppEnv>()
    .openapi(updateRoute, async (c) => {
      const auth = c.get("auth");
      const changes = c.req.valid("json");
      const others = (column: typeof account.username | typeof account.email, value: string) =>
        db
          .select({ id: account.id })
          .from(account)
          .where(
            and(
              isNull(account.deletedAt),
              ne(account.id, auth.account.id),
              eq(sql`lower(${column})`, value.toLowerCase()),
            ),
          )
          .limit(1);
      if (changes.username && (await others(account.username, changes.username)).length > 0) {
        return c.json({ error: "username_taken" }, 409);
      }
      if (changes.email && (await others(account.email, changes.email)).length > 0) {
        return c.json({ error: "email_taken" }, 409);
      }
      const now = new Date();
      const updated = await db.transaction(async (tx) => {
        const [row] = await tx
          .update(account)
          .set({ ...changes, updatedAt: now })
          .where(eq(account.id, auth.account.id))
          .returning();
        if (changes.name) {
          // The athlete's name is what the app shows; stamping the pull cursor sends it to devices.
          await tx
            .update(athlete)
            .set({
              displayName: changes.name,
              updatedAt: now,
              serverUpdatedAt: sql`date_trunc('milliseconds', now())`,
            })
            .where(eq(athlete.id, auth.athleteId));
        }
        return row;
      });
      if (!updated) return c.json({ error: "unauthorized" }, 401);
      return c.json({ athleteId: auth.athleteId, account: await toAccount(updated, storage) }, 200);
    })
    .openapi(passwordRoute, async (c) => {
      const auth = c.get("auth");
      const { currentPassword, newPassword } = c.req.valid("json");
      if (!(await verifyPassword(auth.account.passwordHash, currentPassword))) {
        return c.json({ error: "invalid_credentials" }, 401);
      }
      const passwordHash = await hashPassword(newPassword);
      await db.transaction(async (tx) => {
        await tx
          .update(account)
          .set({ passwordHash, updatedAt: new Date() })
          .where(eq(account.id, auth.account.id));
        // Whoever knew the old password loses access; this device stays signed in.
        await tx
          .update(authSession)
          .set({ revokedAt: new Date() })
          .where(
            and(
              eq(authSession.accountId, auth.account.id),
              ne(authSession.id, auth.sessionId),
              isNull(authSession.revokedAt),
            ),
          );
      });
      return c.body(null, 204);
    })
    .openapi(avatarRoute, async (c) => {
      if (!storage) return c.json({ error: "storage_unavailable" }, 503);
      const auth = c.get("auth");
      if (c.req.header("content-type")?.split(";")[0]?.trim() !== "image/jpeg") {
        return c.json({ error: "not_jpeg" }, 400);
      }
      const bytes = new Uint8Array(await c.req.arrayBuffer());
      if (bytes.length > MAX_AVATAR_BYTES) return c.json({ error: "too_large" }, 413);
      // JPEG files start with FF D8 FF.
      if (bytes.length < 3 || bytes[0] !== 0xff || bytes[1] !== 0xd8 || bytes[2] !== 0xff) {
        return c.json({ error: "not_jpeg" }, 400);
      }
      const key = `avatars/${auth.account.id}/${uuidv7()}.jpg`;
      await storage.put(key, bytes, "image/jpeg");
      const [updated] = await db
        .update(account)
        .set({ avatarKey: key, updatedAt: new Date() })
        .where(eq(account.id, auth.account.id))
        .returning();
      if (!updated) return c.json({ error: "unauthorized" }, 401);
      // The old photo goes away; a failure only leaves an orphan object behind.
      if (auth.account.avatarKey)
        await storage.delete(auth.account.avatarKey).catch(() => undefined);
      return c.json({ athleteId: auth.athleteId, account: await toAccount(updated, storage) }, 200);
    });
}
