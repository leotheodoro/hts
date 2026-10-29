/// Attributes fed by completed sets. Raw values match the Postgres enum `attribute`.
public enum Attribute: String, Codable, Sendable, CaseIterable {
    /// FOR
    case strength
    /// EXP
    case power
    /// GÁS
    case conditioning
    /// COR
    case core
    /// MOB
    case mobility
}

public enum ArcKind: String, Codable, Sendable, CaseIterable {
    case normal
    /// Véspera and other one-off arcs.
    case special
    /// Manutenção: no duration, counts for the streak.
    case filler
}

public enum ArcStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case current
    case completed
}

public enum BlockKind: String, Codable, Sendable, CaseIterable {
    case activation
    case strength
    case combo
    case chainedCombo = "chained_combo"
    case fightRound = "fight_round"
    case conditioning
    case core
    case mobility
    case cardio
}

public enum ExerciseUnit: String, Codable, Sendable, CaseIterable {
    case reps
    case seconds
    case meters
    case minutes
}
