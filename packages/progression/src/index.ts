import rulesJson from "../progression.json" with { type: "json" };

export type RankId = "E" | "D" | "C" | "B" | "A" | "S";

export interface Rank {
  id: RankId;
  name: string;
  minLevel: number;
}

export interface ProgressionRules {
  xp: {
    setCompleted: number;
    sessionCompleted: number;
    personalRecord: number;
    volume: { kgPerXp: number; maxXp: number };
  };
  level: { base: number; exponent: number };
  ranks: Rank[];
}

export const rules = rulesJson as ProgressionRules;

/** Cumulative XP at which level `level` ends (and level + 1 starts). */
export function xpToCompleteLevel(level: number, r: ProgressionRules = rules): number {
  return Math.round(r.level.base * level ** r.level.exponent);
}

export function levelForXp(xp: number, r: ProgressionRules = rules): number {
  let level = 1;
  while (xp >= xpToCompleteLevel(level, r)) level += 1;
  return level;
}

export function rankForLevel(level: number, r: ProgressionRules = rules): Rank {
  let current = r.ranks[0];
  for (const rank of r.ranks) {
    if (level >= rank.minLevel) current = rank;
  }
  if (!current) throw new Error("progression.json has no ranks");
  return current;
}

export interface SessionXpInput {
  completedSets: number;
  personalRecords: number;
  /** Sum of kg × reps over completed sets. */
  volumeKg: number;
}

export interface SessionXp {
  sets: number;
  session: number;
  records: number;
  volume: number;
  total: number;
}

/** XP earned by one completed session. */
export function xpForSession(input: SessionXpInput, r: ProgressionRules = rules): SessionXp {
  const sets = input.completedSets * r.xp.setCompleted;
  const session = r.xp.sessionCompleted;
  const records = input.personalRecords * r.xp.personalRecord;
  const volume = Math.min(Math.floor(input.volumeKg / r.xp.volume.kgPerXp), r.xp.volume.maxXp);
  return { sets, session, records, volume, total: sets + session + records + volume };
}

export interface HistorySet {
  exerciseId: string;
  unit: "reps" | "seconds" | "minutes" | "meters";
  completed: boolean;
  /** Decimal string ("62.5"), or null. */
  weightKg: string | null;
  reps: number | null;
}

export interface SessionProgress {
  completedSets: number;
  /** Decimal string, exact. */
  volumeKg: string;
  /** Exercises whose best load beat every earlier session, in first-seen order. */
  records: string[];
  xp: number;
}

export interface ProgressHistory {
  sessions: SessionProgress[];
  totalXp: number;
  level: number;
  rank: RankId;
}

// Loads are exact decimals: work in hundredths of a kg (numeric(6,2) in Postgres) to avoid float error.
const toCents = (kg: string): bigint => {
  const [whole = "0", fraction = ""] = kg.split(".");
  return BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0").slice(0, 2));
};

const centsToString = (cents: bigint): string => {
  const whole = cents / 100n;
  const fraction = cents % 100n;
  if (fraction === 0n) return whole.toString();
  return `${whole}.${fraction.toString().padStart(2, "0").replace(/0$/, "")}`;
};

/**
 * Derived progress of completed sessions in chronological order (docs/decisions/0010, 0019).
 * Volume is kg × reps of completed rep sets. A record is a load above every earlier session for
 * that exercise; the first time an exercise is logged sets the bar and is not a record.
 */
export function progressHistory(
  sessions: { sets: HistorySet[] }[],
  r: ProgressionRules = rules,
): ProgressHistory {
  const best = new Map<string, bigint>();
  const result: SessionProgress[] = [];
  let totalXp = 0;
  for (const session of sessions) {
    const done = session.sets.filter((s) => s.completed);
    let volumeCents = 0n;
    const sessionBest = new Map<string, bigint>();
    for (const set of done) {
      if (set.weightKg === null) continue;
      const cents = toCents(set.weightKg);
      if (set.unit === "reps" && set.reps !== null) volumeCents += cents * BigInt(set.reps);
      const current = sessionBest.get(set.exerciseId);
      if (current === undefined || cents > current) sessionBest.set(set.exerciseId, cents);
    }
    const records: string[] = [];
    for (const [exerciseId, cents] of sessionBest) {
      const previous = best.get(exerciseId);
      if (previous !== undefined && cents > previous) records.push(exerciseId);
      if (previous === undefined || cents > previous) best.set(exerciseId, cents);
    }
    const volumeKg = centsToString(volumeCents);
    const xp = xpForSession(
      { completedSets: done.length, personalRecords: records.length, volumeKg: Number(volumeKg) },
      r,
    ).total;
    totalXp += xp;
    result.push({ completedSets: done.length, volumeKg, records, xp });
  }
  const level = levelForXp(totalXp, r);
  return { sessions: result, totalXp, level, rank: rankForLevel(level, r).id };
}

export interface StreakSession {
  /** Athlete's calendar day, "YYYY-MM-DD". */
  localDate: string;
  /** Sessions per week of the session's arc; null for filler (Manutenção) arcs. */
  weeklyGoal: number | null;
}

export interface Streak {
  /** Consecutive weeks with the goal met, up to now. The week in progress only adds once met. */
  current: number;
  best: number;
  thisWeek: { done: number; goal: number };
}

const DAY_MS = 86_400_000;
const dayNumber = (date: string) => Date.parse(`${date}T00:00:00Z`) / DAY_MS;
/** Monday of the week, as a day number (1970-01-05 was a Monday). */
const weekStart = (day: number) => day - ((((day - 4) % 7) + 7) % 7);

/**
 * Weekly streak (docs/decisions/0020): weeks run Monday to Sunday; the goal is the weekly goal of the
 * week's arc; filler sessions count and a filler-only week uses the last known goal.
 */
export function streak(sessions: StreakSession[], today: string): Streak {
  const weeks = new Map<number, { done: number; goal: number | null }>();
  for (const s of sessions) {
    const week = weekStart(dayNumber(s.localDate));
    const entry = weeks.get(week) ?? { done: 0, goal: null };
    entry.done += 1;
    if (s.weeklyGoal !== null) entry.goal = Math.max(entry.goal ?? 0, s.weeklyGoal);
    weeks.set(week, entry);
  }
  const current = weekStart(dayNumber(today));
  const first = Math.min(...weeks.keys(), current);
  let lastGoal = 0;
  let run = 0;
  let best = 0;
  let streakBeforeCurrent = 0;
  let thisWeek = { done: 0, goal: 0 };
  for (let week = first; week <= current; week += 7) {
    const entry = weeks.get(week);
    if (entry?.goal != null) lastGoal = entry.goal;
    const goal = entry?.goal ?? lastGoal;
    const done = entry?.done ?? 0;
    const met = done > 0 && done >= goal;
    if (week === current) {
      streakBeforeCurrent = run;
      thisWeek = { done, goal };
      if (met) run += 1;
    } else {
      run = met ? run + 1 : 0;
    }
    best = Math.max(best, run);
  }
  const met = thisWeek.done > 0 && thisWeek.done >= thisWeek.goal;
  return { current: met ? streakBeforeCurrent + 1 : streakBeforeCurrent, best, thisWeek };
}
