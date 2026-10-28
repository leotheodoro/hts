import Foundation

/// Values from `packages/progression/progression.json` (copied by `pnpm sync:shared`).
/// Logic must match `packages/progression/src/index.ts`; both run `packages/fixtures`.
public struct ProgressionRules: Sendable, Decodable {
    public struct XP: Sendable, Decodable {
        public struct Volume: Sendable, Decodable {
            public let kgPerXp: Decimal
            public let maxXp: Int
        }
        public let setCompleted: Int
        public let sessionCompleted: Int
        public let personalRecord: Int
        public let volume: Volume
    }

    public struct Level: Sendable, Decodable {
        public let base: Double
        public let exponent: Double
    }

    public let xp: XP
    public let level: Level
    public let ranks: [Rank]

    /// The bundled rules. A missing or invalid file is a build error, so this traps.
    public static let bundled: ProgressionRules = {
        guard let url = Bundle.module.url(forResource: "progression", withExtension: "json") else {
            fatalError("progression.json missing from HTSDomain resources; run pnpm sync:shared")
        }
        do {
            return try JSONDecoder().decode(ProgressionRules.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Invalid progression.json: \(error)")
        }
    }()
}

public enum RankID: String, Sendable, Decodable, CaseIterable {
    case e = "E", d = "D", c = "C", b = "B", a = "A", s = "S"
}

public struct Rank: Sendable, Decodable, Hashable {
    public let id: RankID
    public let name: String
    public let minLevel: Int
}

public struct SessionXPInput: Sendable, Decodable, Hashable {
    public var completedSets: Int
    public var personalRecords: Int
    /// Sum of kg × reps over completed sets.
    public var volumeKg: Decimal

    public init(completedSets: Int, personalRecords: Int, volumeKg: Decimal) {
        self.completedSets = completedSets
        self.personalRecords = personalRecords
        self.volumeKg = volumeKg
    }
}

public struct SessionXP: Sendable, Decodable, Hashable {
    public let sets: Int
    public let session: Int
    public let records: Int
    public let volume: Int
    public let total: Int
}

public struct Progression: Sendable {
    public let rules: ProgressionRules

    public init(rules: ProgressionRules = .bundled) {
        self.rules = rules
    }

    /// Cumulative XP at which `level` ends (and `level + 1` starts).
    public func xpToComplete(level: Int) -> Int {
        Int((rules.level.base * pow(Double(level), rules.level.exponent)).rounded())
    }

    public func level(forXP xp: Int) -> Int {
        var level = 1
        while xp >= xpToComplete(level: level) { level += 1 }
        return level
    }

    public func rank(forLevel level: Int) -> Rank {
        guard let first = rules.ranks.first else { fatalError("progression.json has no ranks") }
        return rules.ranks.last { level >= $0.minLevel } ?? first
    }

    /// XP earned by one completed session.
    public func xp(for input: SessionXPInput) -> SessionXP {
        let sets = input.completedSets * rules.xp.setCompleted
        let session = rules.xp.sessionCompleted
        let records = input.personalRecords * rules.xp.personalRecord
        let volume = min(Self.floor(input.volumeKg / rules.xp.volume.kgPerXp), rules.xp.volume.maxXp)
        return SessionXP(
            sets: sets, session: session, records: records, volume: volume,
            total: sets + session + records + volume)
    }

    private static func floor(_ value: Decimal) -> Int {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .down)
        return NSDecimalNumber(decimal: result).intValue
    }
}

extension Progression {
    /// Where `xp` sits inside its level, for the XP bar.
    public struct LevelProgress: Hashable, Sendable {
        public let level: Int
        /// Cumulative XP where this level started and where it ends.
        public let start: Int
        public let end: Int
        public let fraction: Double
    }

    public func levelProgress(xp: Int) -> LevelProgress {
        let level = level(forXP: xp)
        let start = level == 1 ? 0 : xpToComplete(level: level - 1)
        let end = xpToComplete(level: level)
        return LevelProgress(
            level: level, start: start, end: end, fraction: Double(xp - start) / Double(max(end - start, 1)))
    }
}
