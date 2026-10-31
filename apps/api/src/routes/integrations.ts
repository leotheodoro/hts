import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { and, eq } from "drizzle-orm";
import type { AppEnv } from "../auth/middleware.js";
import type { Db } from "../db/client.js";
import { integrationConnection } from "../db/schema.js";
import { importGarminActivities } from "../garmin/import.js";
import { parseGarminActivities } from "../garmin/payload.js";
import { error } from "./auth.js";

// Integrations page of the app and the Garmin push (spec 2026-10-31). The Garmin login (OAuth) arrives with
// the approved access (#168); until then connect answers 503.

export interface GarminConfig {
  /** Secret path segment of the push URL registered at Garmin. Without it, the push route answers 404. */
  pushSecret?: string | undefined;
}

const IntegrationSchema = z
  .object({
    provider: z.enum(["garmin"]),
    connected: z.boolean(),
    connectedAt: z.string().nullable(),
    lastActivityAt: z.string().nullable(),
  })
  .openapi("Integration");

const statusRoute = createRoute({
  method: "get",
  path: "/v1/integrations",
  operationId: "listIntegrations",
  tags: ["integrations"],
  summary: "Which platforms the session's account is connected to",
  security: [{ bearer: [] }],
  responses: {
    200: {
      description: "One entry per platform",
      content: {
        "application/json": { schema: z.object({ integrations: z.array(IntegrationSchema) }) },
      },
    },
    401: error("Missing, unknown or revoked session"),
  },
});

const connectRoute = createRoute({
  method: "post",
  path: "/v1/integrations/garmin/connect",
  operationId: "connectGarmin",
  tags: ["integrations"],
  summary: "Start the Garmin login; answers the page to open",
  security: [{ bearer: [] }],
  responses: {
    200: {
      description: "Garmin authorization page",
      content: { "application/json": { schema: z.object({ url: z.string() }) } },
    },
    401: error("Missing, unknown or revoked session"),
    503: error("garmin_unavailable: the Garmin access is not approved yet"),
  },
});

const disconnectRoute = createRoute({
  method: "delete",
  path: "/v1/integrations/garmin",
  operationId: "disconnectGarmin",
  tags: ["integrations"],
  summary: "Forget the Garmin connection and its tokens; imported activities stay",
  security: [{ bearer: [] }],
  responses: {
    204: { description: "Disconnected" },
    401: error("Missing, unknown or revoked session"),
  },
});

export function integrationRoutes(db: Db, garmin: GarminConfig = {}) {
  const routes = new OpenAPIHono<AppEnv>()
    .openapi(statusRoute, async (c) => {
      const [connection] = await db
        .select()
        .from(integrationConnection)
        .where(
          and(
            eq(integrationConnection.accountId, c.get("auth").account.id),
            eq(integrationConnection.provider, "garmin"),
          ),
        );
      return c.json(
        {
          integrations: [
            {
              provider: "garmin" as const,
              connected: connection !== undefined,
              connectedAt: connection?.connectedAt.toISOString() ?? null,
              lastActivityAt: connection?.lastActivityAt?.toISOString() ?? null,
            },
          ],
        },
        200,
      );
    })
    .openapi(connectRoute, (c) => c.json({ error: "garmin_unavailable" }, 503))
    .openapi(disconnectRoute, async (c) => {
      await db
        .delete(integrationConnection)
        .where(
          and(
            eq(integrationConnection.accountId, c.get("auth").account.id),
            eq(integrationConnection.provider, "garmin"),
          ),
        );
      return c.body(null, 204);
    });
  // Outside /v1: Garmin calls it without a session, so the secret path segment is what lets it in. Not in
  // the OpenAPI document, since the app never calls it.
  routes.post("/integrations/garmin/push/:secret", async (c) => {
    if (!garmin.pushSecret || c.req.param("secret") !== garmin.pushSecret) return c.notFound();
    const body = await c.req.json().catch(() => null);
    return c.json(await importGarminActivities(db, parseGarminActivities(body)), 200);
  });
  return routes;
}
