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
