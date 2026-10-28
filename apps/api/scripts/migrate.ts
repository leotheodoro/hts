import { createDb } from "../src/db/client.js";
import { runMigrations } from "../src/db/migrate.js";
import { loadEnv } from "../src/env.js";

const { db, close } = createDb(loadEnv().DATABASE_URL);
await runMigrations(db);
await close();
console.log("Migrations applied");
