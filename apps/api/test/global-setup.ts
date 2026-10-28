import { runMigrations } from "../src/db/migrate.js";
import { createTestDb } from "./db.js";

export default async function setup() {
  const { db, close } = createTestDb();
  await runMigrations(db);
  await close();
}
