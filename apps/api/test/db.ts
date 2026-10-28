import { createDb } from "../src/db/client.js";

export const testDatabaseUrl =
  process.env.TEST_DATABASE_URL ?? "postgres://hts:hts@localhost:5442/hts_test";

export function createTestDb() {
  return createDb(testDatabaseUrl);
}
