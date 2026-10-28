import { OpenAPIHono } from "@hono/zod-openapi";
import type { Db } from "./db/client.js";
import { athleteRoutes } from "./routes/athletes.js";
import { healthRoutes } from "./routes/health.js";
import { version } from "./version.js";

export function createApp({ db }: { db: Db }) {
  const app = new OpenAPIHono();
  app.route("/", healthRoutes);
  app.route("/", athleteRoutes(db));
  return app;
}

export function openApiDocument(app: ReturnType<typeof createApp>) {
  return app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: { title: "Hard To Submit API", version },
    servers: [{ url: "http://localhost:8787", description: "Local" }],
  });
}
