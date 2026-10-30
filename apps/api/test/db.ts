import { inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import { hashPassword } from "../src/auth/password.js";
import { createSession } from "../src/auth/session.js";
import type { Db } from "../src/db/client.js";
import { createDb } from "../src/db/client.js";
import { account, athlete, authSession } from "../src/db/schema.js";

export const testDatabaseUrl =
  process.env.TEST_DATABASE_URL ?? "postgres://hts:hts@localhost:5442/hts_test";

export function createTestDb() {
  return createDb(testDatabaseUrl);
}

export type TestAccount = {
  token: string;
  athleteId: string;
  accountId: string;
  username: string;
  email: string;
  password: string;
};

/** An athlete with an account (random username, e-mail and password) and one live session. */
export async function createTestAccount(
  db: Db,
  overrides: { name?: string } = {},
): Promise<TestAccount> {
  const athleteId = uuidv7();
  const accountId = uuidv7();
  const tag = athleteId.slice(-12);
  const password = `pw-${uuidv7()}`;
  const username = `leo-${tag}`;
  const email = `leo-${tag}@hts.test`;
  const name = overrides.name ?? "Leo";
  await db.insert(athlete).values({ id: athleteId, displayName: name });
  await db.insert(account).values({
    id: accountId,
    athleteId,
    name,
    username,
    email,
    passwordHash: await hashPassword(password),
  });
  const token = await createSession(db, accountId);
  return { token, athleteId, accountId, username, email, password };
}

/** Removes the accounts and sessions of these athletes; run before deleting the athletes. */
export async function removeAccounts(db: Db, athleteIds: string[]) {
  if (athleteIds.length === 0) return;
  const rows = await db
    .select({ id: account.id })
    .from(account)
    .where(inArray(account.athleteId, athleteIds));
  if (rows.length > 0) {
    await db.delete(authSession).where(
      inArray(
        authSession.accountId,
        rows.map((r) => r.id),
      ),
    );
  }
  await db.delete(account).where(inArray(account.athleteId, athleteIds));
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` });
