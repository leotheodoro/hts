import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { and, eq, isNull } from "drizzle-orm";
import type { AppEnv } from "../auth/middleware.js";
import type { Db } from "../db/client.js";
import { athlete } from "../db/schema.js";

export const AthleteSchema = z
  .object({
    id: z.uuid(),
    displayName: z.string().openapi({ example: "Leo" }),
    defaultRestSeconds: z.number().int().openapi({ example: 90 }),
    createdAt: z.iso.datetime(),
    updatedAt: z.iso.datetime(),
  })
  .openapi("Athlete");

const ErrorSchema = z.object({ error: z.string() }).openapi("Error");

const getAthlete = createRoute({
  method: "get",
  path: "/v1/athletes/{id}",
  operationId: "getAthlete",
  tags: ["athletes"],
  summary: "Get an athlete by id",
  security: [{ bearer: [] }],
  request: {
    params: z.object({
      id: z.uuid().openapi({ param: { name: "id", in: "path" } }),
    }),
  },
  responses: {
    200: {
      description: "Athlete found",
      content: { "application/json": { schema: AthleteSchema } },
    },
    401: {
      description: "Missing, unknown or revoked session",
      content: { "application/json": { schema: ErrorSchema } },
    },
    403: {
      description: "Another athlete than the session's",
      content: { "application/json": { schema: ErrorSchema } },
    },
    404: {
      description: "Athlete not found or deleted",
      content: { "application/json": { schema: ErrorSchema } },
    },
  },
});

export function athleteRoutes(db: Db) {
  // A session only reads its own athlete (docs/decisions/0031).
  return new OpenAPIHono<AppEnv>().openapi(getAthlete, async (c) => {
    const { id } = c.req.valid("param");
    if (id !== c.get("auth").athleteId) return c.json({ error: "forbidden" }, 403);
    const [row] = await db
      .select()
      .from(athlete)
      .where(and(eq(athlete.id, id), isNull(athlete.deletedAt)))
      .limit(1);
    if (!row) {
      return c.json({ error: "athlete_not_found" }, 404);
    }
    return c.json(
      {
        id: row.id,
        displayName: row.displayName,
        defaultRestSeconds: row.defaultRestSeconds,
        createdAt: row.createdAt.toISOString(),
        updatedAt: row.updatedAt.toISOString(),
      },
      200,
    );
  });
}
