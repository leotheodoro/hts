import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { version } from "../version.js";

const HealthSchema = z
  .object({
    status: z.literal("ok"),
    version: z.string().openapi({ example: "0.1.0" }),
  })
  .openapi("Health");

const getHealth = createRoute({
  method: "get",
  path: "/health",
  operationId: "getHealth",
  tags: ["system"],
  summary: "Report API status and version",
  responses: {
    200: {
      description: "API is up",
      content: { "application/json": { schema: HealthSchema } },
    },
  },
});

export const healthRoutes = new OpenAPIHono().openapi(getHealth, (c) =>
  c.json({ status: "ok" as const, version }, 200),
);
