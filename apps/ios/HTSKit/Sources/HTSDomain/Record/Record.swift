import Foundation

// The record side of the domain: what was actually done. Number, duration, volume, XP and personal
// records are derived from these rows (docs/decisions/0010, 0017).

public enum SessionStatus: String, Codable, Sendable, CaseIterable {
    case inProgress = "in_progress"
    case completed
}

/// One performed workout. `planSnapshot` freezes the template as it was at the start.
public struct Session: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var athleteId: UUID
    public var arcId: UUID
    public var workoutTemplateId: UUID
    public var status: SessionStatus
    public var startedAt: Date
    public var finishedAt: Date?
    /// The athlete's calendar day when it started, for weekly goals and streaks.
    public var localDate: LocalDate
    public var planSnapshot: PlanSnapshot
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, arcId: UUID, planSnapshot: PlanSnapshot, startedAt: Date, timeZone: TimeZone,
        status: SessionStatus = .inProgress, finishedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.arcId = arcId
        self.workoutTemplateId = planSnapshot.workoutTemplateId
        self.status = status
        self.startedAt = startedAt.roundedToMilliseconds
        self.finishedAt = finishedAt?.roundedToMilliseconds
        self.localDate = LocalDate(startedAt, in: timeZone)
        self.planSnapshot = planSnapshot
        self.createdAt = (createdAt ?? startedAt).roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt ?? startedAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }

    public var duration: TimeInterval? {
        finishedAt.map { $0.timeIntervalSince(startedAt) }
    }
}

/// One set of a prescribed exercise. Values are in the exercise's unit; loads are exact decimals.
public struct LoggedSet: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var athleteId: UUID
    public var sessionId: UUID
    public var prescribedExerciseId: UUID
    public var exerciseId: UUID
    public var setNumber: Int
    public var weightKg: Decimal?
    public var reps: Int?
    public var seconds: Int?
    public var meters: Decimal?
    public var completed: Bool
    public var completedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, sessionId: UUID, prescribedExerciseId: UUID, exerciseId: UUID, setNumber: Int,
        weightKg: Decimal? = nil, reps: Int? = nil, seconds: Int? = nil, meters: Decimal? = nil,
        completed: Bool = false, completedAt: Date? = nil, createdAt: Date, updatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.sessionId = sessionId
        self.prescribedExerciseId = prescribedExerciseId
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.completed = completed
        self.completedAt = completedAt?.roundedToMilliseconds
        self.createdAt = createdAt.roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }
}

/// Fight round block: complete rounds instead of sets, plus the load used per exercise.
public struct LoggedRound: Identifiable, Hashable, Sendable, Codable {
    public struct Weight: Hashable, Sendable, Codable {
        public var exerciseId: UUID
        public var weightKg: Decimal

        public init(exerciseId: UUID, weightKg: Decimal) {
            self.exerciseId = exerciseId
            self.weightKg = weightKg
        }

        private enum CodingKeys: String, CodingKey { case exerciseId, weightKg }

        // Same JSON as the API: lowercase id, load as a decimal string ("24.5").
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            exerciseId = try c.decode(UUID.self, forKey: .exerciseId)
            let text = try c.decode(String.self, forKey: .weightKg)
            guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(forKey: .weightKg, in: c, debugDescription: "Invalid load")
            }
            weightKg = value
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(exerciseId.uuidString.lowercased(), forKey: .exerciseId)
            try c.encode(NSDecimalNumber(decimal: weightKg).stringValue, forKey: .weightKg)
        }
    }

    public var id: UUID
    public var athleteId: UUID
    public var sessionId: UUID
    public var blockId: UUID
    public var roundsCompleted: Int
    public var weights: [Weight]
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, sessionId: UUID, blockId: UUID, roundsCompleted: Int = 0, weights: [Weight] = [],
        createdAt: Date, updatedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.sessionId = sessionId
        self.blockId = blockId
        self.roundsCompleted = roundsCompleted
        self.weights = weights
        self.createdAt = createdAt.roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }
}
