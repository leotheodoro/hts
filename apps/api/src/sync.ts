import { and, eq, gt, sql } from "drizzle-orm";
import { getTableConfig, type PgColumn, type PgTable } from "drizzle-orm/pg-core";
import type { Db } from "./db/client.js";
import {
  arc,
  athlete,
  battle,
  block,
  exercise,
  loggedRound,
  loggedSet,
  prescribedExercise,
  saga,
  session,
  workoutTemplate,
} from "./db/schema.js";

// Sync (docs/decisions/0026): the app sends rows changed since its last push and pulls rows the server
// wrote since its cursor. Rows travel as JSON objects keyed by column name (snake_case), with dates as
// ISO 8601 strings, decimals as strings and jsonb columns as JSON. Last write wins by `updated_at`.

/** Parents before children, so foreign keys hold when a push creates both. */
const TABLES = [
  athlete,
  saga,
  arc,
  workoutTemplate,
  block,
  exercise,
  prescribedExercise,
  session,
  loggedSet,
  loggedRound,
  battle,
] as const;

type SyncTable = (typeof TABLES)[number];

const tableName = (table: PgTable) => getTableConfig(table).name;
export const SYNC_TABLE_NAMES = TABLES.map(tableName);

export type Row = Record<string, unknown>;
export type Changes = Record<string, Row[]>;

const columnsOf = (table: SyncTable) =>
  Object.entries(table as unknown as Record<string, PgColumn>).filter(
    ([, column]) => typeof column === "object" && column !== null && "columnType" in column,
  ) as [string, PgColumn][];

const isTimestamp = (column: PgColumn) => column.columnType === "PgTimestamp";

/** JSON row from the app → values for Drizzle, ignoring unknown and server-only columns. */
function fromWire(table: SyncTable, row: Row): Record<string, unknown> {
  const values: Record<string, unknown> = {};
  for (const [key, column] of columnsOf(table)) {
    if (column.name.startsWith("server_") || !(column.name in row)) continue;
    const value = row[column.name];
    values[key] = isTimestamp(column) && typeof value === "string" ? new Date(value) : value;
  }
  return values;
}

function toWire(table: SyncTable, record: Record<string, unknown>): Row {
  const row: Row = {};
  for (const [key, column] of columnsOf(table)) {
    if (column.name.startsWith("server_")) continue;
    const value = record[key];
    row[column.name] = value instanceof Date ? value.toISOString() : value;
  }
  return row;
}

export class UnknownTableError extends Error {}

/** Upserts every row; a row only replaces the stored one when its `updated_at` is not older. */
export async function push(db: Db, changes: Changes): Promise<number> {
  for (const name of Object.keys(changes)) {
    if (!SYNC_TABLE_NAMES.includes(name)) throw new UnknownTableError(name);
  }
  let applied = 0;
  await db.transaction(async (tx) => {
    for (const table of TABLES) {
      const rows = changes[tableName(table)] ?? [];
      if (rows.length === 0) continue;
      const now = sql`date_trunc('milliseconds', now())`;
      const set: Record<string, unknown> = { serverUpdatedAt: now };
      for (const [key, column] of columnsOf(table)) {
        if (column.name === "id" || column.name.startsWith("server_")) continue;
        set[key] = sql.raw(`excluded."${column.name}"`);
      }
      const values = rows.map((row) => ({ ...fromWire(table, row), serverUpdatedAt: now }));
      const result = await tx
        .insert(table)
        .values(values as never)
        .onConflictDoUpdate({
          target: table.id,
          set: set as never,
          setWhere: sql`${table.updatedAt} <= excluded.updated_at`,
        })
        .returning({ id: table.id });
      applied += result.length;
    }
  });
  return applied;
}

/**
 * Rows of one athlete the server wrote after `since` (all of them when null) and the cursor for the
 * next pull. The athlete row matches by `id`, every other table by `athlete_id`.
 */
export async function pull(
  db: Db,
  athleteId: string,
  since: string | null,
): Promise<{ cursor: string | null; changes: Changes }> {
  const changes: Changes = {};
  let cursor = since;
  for (const table of TABLES) {
    const owner =
      table === athlete ? athlete.id : (table as Exclude<SyncTable, typeof athlete>).athleteId;
    const conditions = [eq(owner, athleteId)];
    if (since) conditions.push(gt(table.serverUpdatedAt, new Date(since)));
    const rows = (await db
      .select()
      .from(table as PgTable)
      .where(and(...conditions))) as Record<string, unknown>[];
    if (rows.length === 0) continue;
    changes[tableName(table)] = rows.map((row) => toWire(table, row));
    for (const row of rows) {
      const written = (row.serverUpdatedAt as Date).toISOString();
      if (cursor === null || written > cursor) cursor = written;
    }
  }
  return { cursor, changes };
}
