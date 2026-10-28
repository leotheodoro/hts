import { OpenAPIHono } from "@hono/zod-openapi";
import { healthRoutes } from "./routes/health.js";
import { version } from "./version.js";

export function createApp() {
  const app = new OpenAPIHono();
  app.route("/", healthRoutes);
  return app;
}

export function openApiDocument(app: ReturnType<typeof createApp>) {
  return app.getOpenAPIDocument({
    openapi: "3.0.3",
    info: { title: "Hard To Submit API", version },
    servers: [{ url: "http://localhost:8787", description: "Local" }],
  });
}
