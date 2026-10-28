import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import type { Db } from "../db/client.js";
import { pull, push, SYNC_TABLE_NAMES, UnknownTableError } from "../sync.js";

const ChangesSchema = z
  .record(z.string(), z.array(z.record(z.string(), z.unknown())))
  .openapi("SyncChanges", {
    description: `Rows by table (${SYNC_TABLE_NAMES.join(", ")}), keyed by column name.`,
  });

const ErrorSchema = z.object({ error: z.string() }).openapi("Error");

const pushRoute = createRoute({
  method: "post",
  path: "/v1/sync/push",
  operationId: "syncPush",
  tags: ["sync"],
  summary: "Upsert rows changed on the device (last write wins by updated_at)",
  security: [{ bearer: [] }],
  request: {
    body: { content: { "application/json": { schema: z.object({ changes: ChangesSchema }) } } },
  },
  responses: {
    200: {
      description: "Rows applied",
      content: { "application/json": { schema: z.object({ applied: z.number().int() }) } },
    },
    400: { description: "Unknown table", content: { "application/json": { schema: ErrorSchema } } },
    401: {
      description: "Missing or wrong bearer token",
      content: { "application/json": { schema: ErrorSchema } },
    },
  },
});

const pullRoute = createRoute({
  method: "get",
  path: "/v1/sync/pull",
  operationId: "syncPull",
  tags: ["sync"],
  summary: "Rows written on the server after the cursor",
  security: [{ bearer: [] }],
  request: {
    query: z.object({ since: z.iso.datetime().optional() }),
  },
  responses: {
    200: {
      description: "Changed rows and the next cursor",
      content: {
        "application/json": {
          schema: z
            .object({ cursor: z.string().nullable(), changes: ChangesSchema })
            .openapi("SyncPull"),
        },
      },
    },
    401: {
      description: "Missing or wrong bearer token",
      content: { "application/json": { schema: ErrorSchema } },
    },
  },
});

export function syncRoutes(db: Db) {
  return new OpenAPIHono()
    .openapi(pushRoute, async (c) => {
      try {
        const applied = await push(db, c.req.valid("json").changes);
        return c.json({ applied }, 200);
      } catch (error) {
        if (error instanceof UnknownTableError)
          return c.json({ error: `unknown_table:${error.message}` }, 400);
        throw error;
      }
    })
    .openapi(pullRoute, async (c) => {
      const { since } = c.req.valid("query");
      return c.json(await pull(db, since ?? null), 200);
    });
}
