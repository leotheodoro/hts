import { z } from "zod";
import { SetTargetSchema } from "./targets.js";

// Copy of the workout template as it was when the session started, so editing the plan later
// never changes history (docs/decisions/0017). Mirrors HTSDomain.PlanSnapshot. Ids point back to
// the plan rows, names and numbers are frozen.
export const PlanSnapshotSchema = z.object({
  workoutTemplateId: z.uuid(),
  letter: z.string(),
  name: z.string(),
  focus: z.string().nullable(),
  blocks: z.array(
    z.object({
      blockId: z.uuid(),
      kind: z.string(),
      attributes: z.array(z.string()),
      durationMinutes: z.number().int().nullable(),
      exercises: z.array(
        z.object({
          prescribedExerciseId: z.uuid(),
          exerciseId: z.uuid(),
          name: z.string(),
          unit: z.string(),
          perSide: z.boolean(),
          setsMin: z.number().int(),
          setsMax: z.number().int(),
          targets: z.array(SetTargetSchema),
          restSeconds: z.number().int().nullable(),
        }),
      ),
    }),
  ),
});

export type PlanSnapshot = z.infer<typeof PlanSnapshotSchema>;
