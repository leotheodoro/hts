/**
 * Key that makes "Barra Fixa", "barra  fixa" and "Bárra fixa" the same catalog exercise
 * (docs/decisions/0016). Must match HTSDomain.ExerciseName.normalize; both run
 * packages/fixtures/normalize-exercise-name.json.
 */
export function normalizeExerciseName(name: string): string {
  return name
    .normalize("NFD")
    .replace(/\p{Mn}/gu, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}
