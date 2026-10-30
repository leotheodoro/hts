import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parseSets, parseTarget } from "../src/seed/notation.js";

type Case = {
  name: string;
  input: { sets: string; target: string };
  expected: { setsMin: number; setsMax: number; targets: unknown[]; perSide: boolean } | null;
};

const fixture = JSON.parse(
  readFileSync(new URL("../../../packages/fixtures/target-notation.json", import.meta.url), "utf8"),
) as { cases: Case[] };

describe("coach notation (shared fixture with TargetNotation.swift)", () => {
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    const sets = parseSets(input.sets);
    const parsed = sets ? parseTarget(input.target, sets.max) : null;
    const actual =
      sets && parsed
        ? { setsMin: sets.min, setsMax: sets.max, targets: parsed.targets, perSide: parsed.perSide }
        : null;
    expect(actual).toEqual(expected);
  });
});
