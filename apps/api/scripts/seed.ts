import { existsSync, readFileSync } from "node:fs";
import { z } from "zod";
import { createDb } from "../src/db/client.js";
import { seedAccount } from "../src/seed/account.js";
import { importStarterPlan, StarterPlanFileSchema } from "../src/seed/starter-plan.js";

// Creates (or updates) the account from SEED_* and imports the coach's plan into it.
// Usage: pnpm --filter api db:seed. The password and DATABASE_URL come from the environment
// (apps/api/.env locally), never from the repository.
const env = z
  .object({
    DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
    SEED_NAME: z.string().min(1),
    SEED_USERNAME: z.string().min(1),
    SEED_EMAIL: z.email(),
    SEED_PASSWORD: z.string().min(8),
  })
  .parse(process.env);

const planFile = new URL("../seed/starter-plan.json", import.meta.url);
const today = new Date().toLocaleDateString("en-CA");
const { db, close } = createDb(env.DATABASE_URL);
try {
  const { athleteId } = await seedAccount(db, {
    name: env.SEED_NAME,
    username: env.SEED_USERNAME,
    email: env.SEED_EMAIL,
    password: env.SEED_PASSWORD,
  });
  console.log(`Account ${env.SEED_USERNAME} ready (athlete ${athleteId}).`);
  if (existsSync(planFile)) {
    const plan = StarterPlanFileSchema.parse(JSON.parse(readFileSync(planFile, "utf8")));
    const result = await importStarterPlan(db, athleteId, plan, today);
    console.log(`Plan: ${result.arcsAdded} arcs added, ${result.videosFilled} videos filled.`);
  } else {
    console.log("No seed/starter-plan.json: account only.");
  }
} finally {
  await close();
}
