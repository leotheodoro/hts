// Applies pending migrations, then exits. Runs before the server on every deploy (docs/decisions/0025).
import { createDb } from "./db/client.js";
import { runMigrations } from "./db/migrate.js";
import { loadEnv } from "./env.js";

const { db, close } = createDb(loadEnv().DATABASE_URL);
await runMigrations(db);
await close();
console.log("Migrations applied");
