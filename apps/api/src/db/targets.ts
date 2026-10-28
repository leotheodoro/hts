import { z } from "zod";

// Target of one set, in the exercise's unit (reps, seconds, meters or minutes); per side when the
// exercise is. Notation → value: "8" fixed, "10-20 s" range, "máx" max (docs/decisions/0014).
// Mirrors HTSDomain.SetTarget.
export const SetTargetSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("fixed"), value: z.number().positive() }),
  z
    .object({ type: z.literal("range"), min: z.number().positive(), max: z.number().positive() })
    .refine((t) => t.min < t.max, "min must be below max"),
  z.object({ type: z.literal("max") }),
]);

export type SetTarget = z.infer<typeof SetTargetSchema>;

/** Targets are either one for every set or one per set up to `setsMax`. */
export function targetsFitSets(targets: SetTarget[], setsMax: number): boolean {
  return targets.length === 1 || targets.length === setsMax;
}
