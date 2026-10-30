import { eq, sql } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { hashPassword } from "../auth/password.js";
import type { Db } from "../db/client.js";
import { account, athlete } from "../db/schema.js";

export type SeedCredentials = { name: string; username: string; email: string; password: string };

/**
 * Creates the account and its athlete, or updates them when the username exists (ignoring case):
 * running the seed again changes the name, e-mail or password without touching the data.
 */
export async function seedAccount(
  db: Db,
  credentials: SeedCredentials,
): Promise<{ accountId: string; athleteId: string }> {
  const name = credentials.name.trim();
  const username = credentials.username.trim();
  const email = credentials.email.trim();
  const passwordHash = await hashPassword(credentials.password);
  return db.transaction(async (tx) => {
    const now = new Date();
    const [existing] = await tx
      .select()
      .from(account)
      .where(
        sql`lower(${account.username}) = ${username.toLowerCase()} AND ${account.deletedAt} IS NULL`,
      )
      .limit(1);
    if (existing) {
      await tx
        .update(account)
        .set({ name, username, email, passwordHash, updatedAt: now })
        .where(eq(account.id, existing.id));
      await tx
        .update(athlete)
        .set({
          displayName: name,
          updatedAt: now,
          serverUpdatedAt: sql`date_trunc('milliseconds', now())`,
        })
        .where(eq(athlete.id, existing.athleteId));
      return { accountId: existing.id, athleteId: existing.athleteId };
    }
    const athleteId = uuidv7();
    const accountId = uuidv7();
    await tx.insert(athlete).values({ id: athleteId, displayName: name });
    await tx
      .insert(account)
      .values({ id: accountId, athleteId, name, username, email, passwordHash });
    return { accountId, athleteId };
  });
}
