import { serve } from "@hono/node-server";
import { createApp } from "./app.js";
import { createDb } from "./db/client.js";
import { loadEnv } from "./env.js";
import { s3Storage } from "./storage.js";

const env = loadEnv();
const { db } = createDb(env.DATABASE_URL);
const app = createApp({
  db,
  storage: s3Storage(env),
  garmin: { pushSecret: env.GARMIN_PUSH_SECRET },
});

serve({ fetch: app.fetch, port: env.PORT, hostname: "0.0.0.0" }, (info) => {
  console.log(`API listening on http://localhost:${info.port}`);
});
