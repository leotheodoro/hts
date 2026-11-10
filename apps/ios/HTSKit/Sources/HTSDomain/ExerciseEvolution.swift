import Foundation

/// Estimated one-rep max (#202).
public enum OneRepMax {
    /// Epley: kg × (1 + reps ÷ 30). A single rep is the max itself.
    public static func epley(weightKg: Decimal, reps: Int) -> Decimal {
        reps <= 1 ? weightKg : weightKg + weightKg * Decimal(reps) / 30
    }
}

/// One catalog exercise over time, for the Evolução page (#202): its workouts in date order, each reduced to the
/// set with the highest estimated max.
public struct ExerciseEvolution: Hashable, Sendable, Identifiable {
    public struct Lift: Hashable, Sendable {
        public let weightKg: Decimal
        public let reps: Int

        public init(weightKg: Decimal, reps: Int) {
            self.weightKg = weightKg
            self.reps = reps
        }

        public var estimatedMax: Decimal { OneRepMax.epley(weightKg: weightKg, reps: reps) }

        /// What changed from `earlier`: "+10 kg e uma repetição a mais".
        public func gain(over earlier: Lift) -> Gain {
            Gain(kg: weightKg - earlier.weightKg, reps: reps - earlier.reps)
        }
    }

    public struct Gain: Hashable, Sendable {
        public let kg: Decimal
        public let reps: Int

        public init(kg: Decimal, reps: Int) {
            self.kg = kg
            self.reps = reps
        }
    }

    public struct Workout: Hashable, Sendable {
        public let date: Date
        public let best: Lift
        public let heaviestKg: Decimal
        public var estimatedMax: Decimal { best.estimatedMax }

        /// Nil when the workout has no set with kg and reps.
        public init?(date: Date, sets: [Lift]) {
            guard let best = sets.max(by: { $0.estimatedMax < $1.estimatedMax }),
                let heaviest = sets.map(\.weightKg).max()
            else { return nil }
            self.date = date
            self.best = best
            self.heaviestKg = heaviest
        }
    }

    public static let month: TimeInterval = 30 * 86_400

    public let exerciseId: UUID
    public let name: String
    /// Oldest first.
    public let workouts: [Workout]
    public var id: UUID { exerciseId }

    public init(exerciseId: UUID, name: String, workouts: [Workout]) {
        self.exerciseId = exerciseId
        self.name = name
        self.workouts = workouts.sorted { $0.date < $1.date }
    }

    public var first: Workout? { workouts.first }
    public var latest: Workout? { workouts.last }
    public var heaviest: Workout? { workouts.max { $0.heaviestKg < $1.heaviestKg } }
    public var bestEstimatedMax: Workout? { workouts.max { $0.estimatedMax < $1.estimatedMax } }

    /// The best workout up to 30 days before `now`; nil when the exercise is newer than that.
    public func monthAgo(now: Date) -> Workout? {
        workouts.filter { $0.date <= now - Self.month }.max { $0.estimatedMax < $1.estimatedMax }
    }

    /// The latest estimated max minus the one a month ago; nil when there is nothing a month ago.
    public func change(now: Date) -> Decimal? {
        guard let latest, let then = monthAgo(now: now) else { return nil }
        return latest.estimatedMax - then.estimatedMax
    }
}
