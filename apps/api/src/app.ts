import { OpenAPIHono } from "@hono/zod-openapi";
import { type AppEnv, sessionAuth } from "./auth/middleware.js";
import { LoginLimiter } from "./auth/rate-limit.js";
import type { Db } from "./db/client.js";
import { athleteRoutes } from "./routes/athletes.js";
import { authRoutes } from "./routes/auth.js";
import { healthRoutes } from "./routes/health.js";
import { syncRoutes } from "./routes/sync.js";
import { version } from "./version.js";

export function createApp({ db }: { db: Db }) {
  const app = new OpenAPIHono<AppEnv>();
  app.openAPIRegistry.registerComponent("securitySchemes", "bearer", {
    type: "http",
    scheme: "bearer",
  });
  app.route("/", healthRoutes);
  app.use("/v1/*", sessionAuth(db));
  app.route("/", authRoutes(db, new LoginLimiter()));
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
