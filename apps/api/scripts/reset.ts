import { sql } from "drizzle-orm";
import { createDb } from "../src/db/client.js";

// Deletes every row of every user table, accounts and sessions included. Irreversible.
// Usage: pnpm --filter api db:reset -- --yes
if (!process.argv.includes("--yes")) {
  console.error("Refusing to delete all data without --yes.");
  process.exit(1);
}
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is not set.");
  process.exit(1);
}
const { db, close } = createDb(url);
try {
  await db.execute(sql`
    TRUNCATE auth_session, account, logged_round, logged_set, session, battle,
      prescribed_exercise, exercise, block, workout_template, arc, season, athlete CASCADE
  `);
  console.log(`All data deleted on ${new URL(url).host}.`);
} finally {
  await close();
}
