import { OpenAPIHono } from "@hono/zod-openapi";
import { bearerAuth } from "./auth.js";
import type { Db } from "./db/client.js";
import { athleteRoutes } from "./routes/athletes.js";
import { healthRoutes } from "./routes/health.js";
import { syncRoutes } from "./routes/sync.js";
import { version } from "./version.js";

export function createApp({ db, apiToken }: { db: Db; apiToken: string }) {
  const app = new OpenAPIHono();
  app.openAPIRegistry.registerComponent("securitySchemes", "bearer", {
    type: "http",
    scheme: "bearer",
  });
  app.route("/", healthRoutes);
  app.use("/v1/*", bearerAuth(apiToken));
  app.route("/", athleteRoutes(db));
  app.route("/", syncRoutes(db));
  return app;
}

export function openApiDocument(app: ReturnType<typeof createApp>) {
  return app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: { title: "Hard To Submit API", version },
    servers: [{ url: "http://localhost:8787", description: "Local" }],
  });
}
