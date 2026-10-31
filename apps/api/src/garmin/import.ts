import { and, eq, sql } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { Db } from "../db/client.js";
import { account, importedActivity, integrationConnection } from "../db/schema.js";
import type { GarminActivity } from "./payload.js";

/**
 * Writes pushed activities into the athlete of the connected account (docs/decisions/0033). A repeated
 * summary updates its row (unique source + external id); an unknown Garmin user is ignored, so Garmin does
 * not keep retrying. Each write stamps `server_updated_at`, which the app's next pull picks up.
 */
export async function importGarminActivities(
  db: Db,
  activities: GarminActivity[],
): Promise<{ imported: number; ignored: number }> {
  let imported = 0;
  let ignored = 0;
  for (const activity of activities) {
    const [owner] = await db
      .select({ connectionId: integrationConnection.id, athleteId: account.athleteId })
      .from(integrationConnection)
      .innerJoin(account, eq(account.id, integrationConnection.accountId))
      .where(
        and(
          eq(integrationConnection.provider, "garmin"),
          eq(integrationConnection.externalUserId, activity.userId),
        ),
      );
    if (!owner) {
      ignored += 1;
      continue;
    }
    const now = sql`date_trunc('milliseconds', now())`;
    const values = {
      activityType: activity.activityType,
      name: activity.name,
      startedAt: activity.startedAt,
      durationSeconds: activity.durationSeconds,
      distanceMeters: activity.distanceMeters === null ? null : activity.distanceMeters.toFixed(2),
      averageHeartRate: activity.averageHeartRate,
      calories: activity.calories,
      deletedAt: activity.deleted ? now : null,
      updatedAt: now,
      serverUpdatedAt: now,
    };
    await db
      .insert(importedActivity)
      .values({
        id: uuidv7(),
        athleteId: owner.athleteId,
        source: "garmin",
        externalId: activity.summaryId,
        ...values,
      })
      .onConflictDoUpdate({
        target: [importedActivity.source, importedActivity.externalId],
        set: values,
        // A summary id never moves to another athlete.
        setWhere: eq(importedActivity.athleteId, owner.athleteId),
      });
    if (!activity.deleted) {
      await db
        .update(integrationConnection)
        .set({
          lastActivityAt: sql`greatest(${integrationConnection.lastActivityAt}, ${activity.startedAt.toISOString()}::timestamptz)`,
        })
        .where(eq(integrationConnection.id, owner.connectionId));
    }
    imported += 1;
  }
  return { imported, ignored };
}
