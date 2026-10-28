import { writeFileSync } from "node:fs";
import { is } from "drizzle-orm";
import { getTableConfig, PgTable } from "drizzle-orm/pg-core";
import * as schema from "../src/db/schema.js";

// Column names and nullability of every table, so the iOS tests can check that the SQLite schema
// mirrors Postgres (docs/decisions/0009). Types differ by design (jsonb -> TEXT, enum -> TEXT).
const tables = (Object.values(schema) as unknown[])
  .filter((value): value is PgTable => is(value, PgTable))
  .map((table) => getTableConfig(table))
  .sort((a, b) => a.name.localeCompare(b.name))
  .map((config) => ({
    name: config.name,
    columns: config.columns.map((c) => ({ name: c.name, notNull: c.notNull || c.primary })),
  }));

const out = new URL("../../../packages/contracts/db-schema.json", import.meta.url);
writeFileSync(out, `${JSON.stringify({ tables }, null, 2)}\n`);
console.log(`Wrote ${out.pathname}`);
