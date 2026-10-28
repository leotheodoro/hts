import Foundation

/// One set as progress sees it. Mirrors `HistorySet` in packages/progression.
public struct HistorySet: Hashable, Sendable, Decodable {
    public let exerciseId: String
    public let unit: ExerciseUnit
    public let completed: Bool
    public let weightKg: Decimal?
    public let reps: Int?

    public init(exerciseId: String, unit: ExerciseUnit, completed: Bool, weightKg: Decimal?, reps: Int?) {
        self.exerciseId = exerciseId
        self.unit = unit
        self.completed = completed
        self.weightKg = weightKg
        self.reps = reps
    }

    private enum CodingKeys: String, CodingKey { case exerciseId, unit, completed, weightKg, reps }

    /// Loads are decimal strings in the shared fixtures, like in the API.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exerciseId = try c.decode(String.self, forKey: .exerciseId)
        unit = try c.decode(ExerciseUnit.self, forKey: .unit)
        completed = try c.decode(Bool.self, forKey: .completed)
        weightKg = try c.decodeIfPresent(String.self, forKey: .weightKg).flatMap {
            Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX"))
        }
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
    }
}

public struct SessionProgress: Hashable, Sendable {
    public let completedSets: Int
    public let volumeKg: Decimal
    /// Exercises whose best load beat every earlier session, in first-seen order.
    public let records: [String]
    public let xp: Int
}

public struct ProgressHistory: Hashable, Sendable {
    public let sessions: [SessionProgress]
    public let totalXp: Int
    public let level: Int
    public let rank: Rank
}

extension Progression {
    /// Derived progress of completed sessions in chronological order (docs/decisions/0010, 0019). Must match
    /// `progressHistory` in packages/progression; both run packages/fixtures/progress-history.json.
    public func history(_ sessions: [[HistorySet]]) -> ProgressHistory {
        var best: [String: Decimal] = [:]
        var results: [SessionProgress] = []
        var total = 0
        for sets in sessions {
            let done = sets.filter(\.completed)
            var volume: Decimal = 0
            var order: [String] = []
            var sessionBest: [String: Decimal] = [:]
            for set in done {
                guard let weight = set.weightKg else { continue }
                if set.unit == .reps, let reps = set.reps { volume += weight * Decimal(reps) }
                if sessionBest[set.exerciseId] == nil { order.append(set.exerciseId) }
                if weight > sessionBest[set.exerciseId] ?? -1 { sessionBest[set.exerciseId] = weight }
            }
            var records: [String] = []
            for exerciseId in order {
                let weight = sessionBest[exerciseId]!
                if let previous = best[exerciseId] {
                    if weight > previous {
                        records.append(exerciseId)
                        best[exerciseId] = weight
                    }
                } else {
                    best[exerciseId] = weight
                }
            }
            let xp = self.xp(
                for: SessionXPInput(completedSets: done.count, personalRecords: records.count, volumeKg: volume)
            ).total
            total += xp
            results.append(SessionProgress(completedSets: done.count, volumeKg: volume, records: records, xp: xp))
        }
        let level = level(forXP: total)
        return ProgressHistory(sessions: results, totalXp: total, level: level, rank: rank(forLevel: level))
    }
}
