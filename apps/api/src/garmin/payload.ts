import { z } from "zod";

// The Garmin push of activity summaries (Activity API 2.1, sections 4 and 6.1-6.2): every field the import
// needs is read here and nowhere else. The push carries no deletions: an activity deleted at Garmin stays.

const ActivitySchema = z.object({
  userId: z.string(),
  summaryId: z.string(),
  activityType: z.string(),
  activityName: z.string().optional(),
  startTimeInSeconds: z.number().int(),
  durationInSeconds: z.number().int().nonnegative(),
  distanceInMeters: z.number().nonnegative().optional(),
  averageHeartRateInBeatsPerMinute: z.number().optional(),
  activeKilocalories: z.number().int().nonnegative().optional(),
  /** A multisport activity: its parts arrive as their own summaries, so it does not count itself. */
  isParent: z.boolean().optional(),
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
  isParent: boolean;
}

/** A sensor glitch must not drop the activity: an impossible average heart rate is left out. */
const heartRate = (value: number | undefined) =>
  value !== undefined && Number.isInteger(value) && value > 0 && value <= 250 ? value : null;

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
        averageHeartRate: heartRate(a.averageHeartRateInBeatsPerMinute),
        calories: a.activeKilocalories ?? null,
        isParent: a.isParent ?? false,
      },
    ];
  });
}

const DeregistrationsSchema = z.object({
  deregistrations: z.array(z.object({ userId: z.string() }).passthrough()),
});

/** Garmin users who removed their consent in Garmin Connect (the Deregistrations endpoint). */
export function parseGarminDeregistrations(body: unknown): string[] {
  const parsed = DeregistrationsSchema.safeParse(body);
  return parsed.success ? parsed.data.deregistrations.map((d) => d.userId) : [];
}
