import { z } from "zod";

// The Garmin push of activity summaries, as documented publicly for the Health/Activity API. Provisional
// until Garmin approves the access and the official documentation confirms the names (#168): every field
// the import needs is read here and nowhere else.

const ActivitySchema = z.object({
  userId: z.string(),
  summaryId: z.string(),
  activityType: z.string(),
  activityName: z.string().optional(),
  startTimeInSeconds: z.number().int(),
  durationInSeconds: z.number().int().nonnegative(),
  distanceInMeters: z.number().nonnegative().optional(),
  averageHeartRateInBeatsPerMinute: z.number().int().positive().optional(),
  activeKilocalories: z.number().int().nonnegative().optional(),
  /** Assumed deletion marker; the real one comes from the official documentation (#168). */
  deleted: z.boolean().optional(),
});

const PushSchema = z.object({
  activities: z.array(z.unknown()).optional(),
  manuallyUpdatedActivities: z.array(z.unknown()).optional(),
});

export interface GarminActivity {
  userId: string;
  summaryId: string;
  activityType: string;
  name: string | null;
  startedAt: Date;
  durationSeconds: number;
  distanceMeters: number | null;
  averageHeartRate: number | null;
  calories: number | null;
  deleted: boolean;
}

/** The activities of one push. Items that do not parse are skipped, so one bad item never drops the rest. */
export function parseGarminActivities(body: unknown): GarminActivity[] {
  const push = PushSchema.safeParse(body);
  if (!push.success) return [];
  const items = [...(push.data.activities ?? []), ...(push.data.manuallyUpdatedActivities ?? [])];
  return items.flatMap((item) => {
    const parsed = ActivitySchema.safeParse(item);
    if (!parsed.success) return [];
    const a = parsed.data;
    return [
      {
        userId: a.userId,
        summaryId: a.summaryId,
        activityType: a.activityType.toUpperCase(),
        name: a.activityName ?? null,
        startedAt: new Date(a.startTimeInSeconds * 1000),
        durationSeconds: a.durationInSeconds,
        distanceMeters: a.distanceInMeters ?? null,
        averageHeartRate: a.averageHeartRateInBeatsPerMinute ?? null,
        calories: a.activeKilocalories ?? null,
        deleted: a.deleted ?? false,
      },
    ];
  });
}
