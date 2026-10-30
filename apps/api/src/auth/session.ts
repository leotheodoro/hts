import { createHash, randomBytes } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { Db } from "../db/client.js";
import { account, authSession } from "../db/schema.js";

export type AccountRow = typeof account.$inferSelect;
export type AuthContext = { account: AccountRow; athleteId: string; sessionId: string };

const TOUCH_AFTER_MS = 60 * 60 * 1000;

/** SHA-256 in hex: the only form of a token the database ever sees. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/** Starts a session and returns its token (32 random bytes, base64url). It lasts until revoked. */
export async function createSession(db: Db, accountId: string): Promise<string> {
  const token = randomBytes(32).toString("base64url");
  await db.insert(authSession).values({ id: uuidv7(), accountId, tokenHash: hashToken(token) });
  return token;
}

/** The live session of a token and its account, or null. Marks it used at most once an hour. */
export async function resolveSession(db: Db, token: string): Promise<AuthContext | null> {
  const [row] = await db
    .select({ session: authSession, account })
    .from(authSession)
    .innerJoin(account, eq(account.id, authSession.accountId))
    .where(
      and(
        eq(authSession.tokenHash, hashToken(token)),
        isNull(authSession.revokedAt),
        isNull(account.deletedAt),
      ),
    )
    .limit(1);
  if (!row) return null;
  if (Date.now() - row.session.lastUsedAt.getTime() > TOUCH_AFTER_MS) {
    await db
      .update(authSession)
      .set({ lastUsedAt: new Date() })
      .where(eq(authSession.id, row.session.id));
  }
  return { account: row.account, athleteId: row.account.athleteId, sessionId: row.session.id };
}

export async function revokeSession(db: Db, sessionId: string): Promise<void> {
  await db.update(authSession).set({ revokedAt: new Date() }).where(eq(authSession.id, sessionId));
}
