import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  type HistorySet,
  levelForXp,
  type ProgressHistory,
  progressHistory,
  rankForLevel,
  type SessionXpInput,
  type Streak,
  type StreakSession,
  streak,
  type TitleSession,
  titles,
  type UnlockedTitle,
  xpForSession,
} from "../src/index.js";

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

describe("progressHistory", () => {
  const fixture = load<{ sessions: { sets: HistorySet[] }[] }, ProgressHistory>(
    "progress-history.json",
  );
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(progressHistory(input.sessions)).toEqual(expected);
  });
});

describe("streak", () => {
  const fixture = load<{ today: string; sessions: StreakSession[] }, Streak>("streak.json");
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(streak(input.sessions, input.today)).toEqual(expected);
  });
});

describe("titles", () => {
  const fixture = load<{ sessions: TitleSession[] }, { titles: UnlockedTitle[] }>("titles.json");
  it.each(fixture.cases)("$name", ({ input, expected }) => {
    expect(titles(input.sessions)).toEqual(expected.titles);
  });
});
