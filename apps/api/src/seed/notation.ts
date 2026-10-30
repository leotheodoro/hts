import type { SetTarget } from "../db/targets.js";

// The coach's notation, ported from HTSDomain.TargetNotation (docs/decisions/0014). Both run
// packages/fixtures/target-notation.json; change them together.
//
// | Typed     | Sets  | Targets                          | Per side |
// | --------- | ----- | -------------------------------- | -------- |
// | `8`       | any   | fixed 8                          | no       |
// | `6-6-3-3` | 4     | fixed 6, 6, 3, 3                 | no       |
// | `10-20`   | not 2 | range 10 to 20                   | no       |
// | `15 a 20` | any   | range 15 to 20                   | no       |
// | `12/12`   | any   | fixed 12                         | yes      |
// | `máx`     | any   | max                              | no       |
//
// Unit suffixes (`s`, `seg`, `min`, `m`) are accepted and ignored: the unit belongs to the exercise.

export type Sets = { min: number; max: number };
export type ParsedTarget = { targets: SetTarget[]; perSide: boolean };

const INTEGER = /^[+-]?\d+$/;
const DECIMAL = /^[+-]?(\d+\.?\d*|\.\d+)$/;

function number(part: string): number | null {
  const text = part.trim().replaceAll(",", ".");
  return DECIMAL.test(text) ? Number(text) : null;
}

/** "3", "3-4" or "3 a 4". */
export function parseSets(text: string): Sets | null {
  const parts = text
    .toLowerCase()
    .replaceAll(" a ", "-")
    .split("-")
    .filter((p) => p.length > 0)
    .map((p) => p.trim());
  const numbers = parts.filter((p) => INTEGER.test(p)).map(Number);
  if (numbers.length !== parts.length || numbers.length < 1 || numbers.length > 2) return null;
  if (!numbers.every((n) => n > 0)) return null;
  const sets = { min: numbers[0] as number, max: numbers[numbers.length - 1] as number };
  return sets.min <= sets.max ? sets : null;
}

/** Null when the text is not a target, or when a per-set list does not match `setsMax`. */
export function parseTarget(text: string, setsMax: number): ParsedTarget | null {
  let body = text.toLowerCase().trim();
  for (const suffix of ["seg", "min", "s", "m"]) {
    if (body.endsWith(suffix)) {
      body = body.slice(0, -suffix.length).trim();
      break;
    }
  }
  if (["máx", "max", "máximo", "maximo"].includes(body)) {
    return { targets: [{ type: "max" }], perSide: false };
  }
  if (body.includes(" a ")) {
    const bounds = body.split(" a ").map(number);
    const [min, max] = bounds;
    if (bounds.length !== 2 || min == null || max == null || min <= 0 || min >= max) return null;
    return { targets: [{ type: "range", min, max }], perSide: false };
  }
  if (body.includes("/")) {
    const sides = body
      .split("/")
      .filter((p) => p.length > 0)
      .map(number)
      .filter((n): n is number => n !== null);
    const [left, right] = sides;
    if (sides.length !== 2 || left === undefined || left !== right || left <= 0) return null;
    return { targets: [{ type: "fixed", value: left }], perSide: true };
  }
  const parts = body.split("-");
  const numbers = parts.map(number).filter((n): n is number => n !== null);
  if (numbers.length === 0 || numbers.length !== parts.length || !numbers.every((n) => n > 0)) {
    return null;
  }
  const [first, second] = numbers as [number, number];
  if (numbers.length === 1) return { targets: [{ type: "fixed", value: first }], perSide: false };
  if (numbers.length === 2 && first < second && setsMax !== 2) {
    return { targets: [{ type: "range", min: first, max: second }], perSide: false };
  }
  if (numbers.length !== setsMax) return null;
  return { targets: numbers.map((value) => ({ type: "fixed", value })), perSide: false };
}
