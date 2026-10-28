import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { levelForXp, rankForLevel, type SessionXpInput, xpForSession } from "../src/index.js";

interface Fixture<I, E> {
  function: string;
  cases: { name: string; input: I; expected: E }[];
}

function load<I, E>(file: string): Fixture<I, E> {
  const url = new URL(`../../fixtures/${file}`, import.meta.url);
  return JSON.parse(readFileSync(url, "utf8")) as Fixture<I, E>;
}

describe("levelForXp", () => {
  const fixture = load<{ xp: number }, { level: number }>("level-for-xp.json");
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(levelForXp(input.xp)).toBe(expected.level);
  });
});

describe("rankForLevel", () => {
  const fixture = load<{ level: number }, { id: string; name: string }>("rank-for-level.json");
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    const { id, name } = rankForLevel(input.level);
    expect({ id, name }).toEqual(expected);
  });
});

describe("xpForSession", () => {
  const fixture = load<SessionXpInput, ReturnType<typeof xpForSession>>("xp-for-session.json");
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(xpForSession(input)).toEqual(expected);
  });
});
