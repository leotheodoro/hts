import { z } from "zod";

const EnvSchema = z.object({
  DATABASE_URL: z.url({ protocol: /^postgres(ql)?$/ }),
  PORT: z.coerce.number().int().positive().default(8787),
  /** Private, S3-compatible bucket for account photos (#142). Optional: without it, uploads answer 503. */
  AWS_ENDPOINT_URL_S3: z.url().optional(),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  AWS_REGION: z.string().optional(),
  S3_BUCKET: z.string().optional(),
  /** Secret path segment of the Garmin push URL (#163). Optional: without it, the push route answers 404. */
  GARMIN_PUSH_SECRET: z.string().optional(),
  /** Garmin app credentials (#168). Without them, "Conectar Garmin" answers 503. */
  GARMIN_CLIENT_ID: z.string().optional(),
  GARMIN_CLIENT_SECRET: z.string().optional(),
  /** Must match the OAuth redirect URL registered on the Garmin app exactly. */
  GARMIN_REDIRECT_URI: z.url().default("https://api.hardtosubmit.com/integrations/garmin/callback"),
});

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const result = EnvSchema.safeParse(source);
  if (!result.success) {
    throw new Error(`Invalid environment:\n${z.prettifyError(result.error)}`);
  }
  return result.data;
}
