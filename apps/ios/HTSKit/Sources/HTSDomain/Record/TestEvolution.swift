import Foundation

/// One run of a treino teste (#216): its day, the exercises of its snapshot and its sets.
public struct TestRun: Hashable, Sendable {
    public let date: LocalDate
    public let exercises: [PlanSnapshot.Exercise]
    public let sets: [LoggedSet]

    public init(date: LocalDate, exercises: [PlanSnapshot.Exercise], sets: [LoggedSet]) {
        self.date = date
        self.exercises = exercises
        self.sets = sets
    }
}

/// EVOLUÇÃO of a treino teste (#216): the last run side by side with the one before. Each exercise shows its best
/// completed set: the load when there is one, otherwise the amount in the exercise's unit. More is better, except on
/// timed tests where the lowest value wins (#218).
public struct TestEvolution: Hashable, Sendable {
    public enum Trend: Hashable, Sendable { case better, worse, same }

    public struct Row: Hashable, Sendable {
        public let name: String
        public let previous: String?
        public let latest: String?
        /// "+8 s", "−5 s", "=".
        public let delta: String?
        public let trend: Trend?

        public init(name: String, previous: String?, latest: String?, delta: String?, trend: Trend?) {
            self.name = name
            self.previous = previous
            self.latest = latest
            self.delta = delta
            self.trend = trend
        }
    }

    public let latestDate: LocalDate
    public let previousDate: LocalDate?
    public let rows: [Row]

    /// `runs` newest first; nil when the test was never done.
    public init?(runs: [TestRun]) {
        guard let latest = runs.first else { return nil }
        let previous = runs.dropFirst().first
        latestDate = latest.date
        previousDate = previous?.date
        rows = latest.exercises.map { exercise in
            let now = Measure.best(latest.sets, of: exercise)
            let before = previous.flatMap { Measure.best($0.sets, of: exercise) }
            var delta: String?
            var trend: Trend?
            if let now, let before, now.isLoad == before.isLoad {
                // A lower time is the better one on timed tests (#218); the delta keeps its real sign.
                let gain = now.value - before.value
                let difference = exercise.lowerIsBetter == true && !now.isLoad ? -gain : gain
                trend = difference > 0 ? .better : difference < 0 ? .worse : .same
                delta = Measure(value: abs(gain), unit: now.unit, isLoad: now.isLoad).deltaText(
                    sign: gain > 0 ? "+" : gain < 0 ? "−" : nil)
            }
            return Row(
                name: exercise.name, previous: before?.text, latest: now?.text, delta: delta, trend: trend)
        }
    }
}

/// The best set of one exercise: the heaviest load, or the most reps, seconds, meters or calories.
private struct Measure {
    let value: Decimal
    let unit: ExerciseUnit
    let isLoad: Bool

    static func best(_ sets: [LoggedSet], of exercise: PlanSnapshot.Exercise) -> Measure? {
        let done = sets.filter { $0.completed && $0.exerciseId == exercise.exerciseId }
        if let load = done.compactMap(\.weightKg).filter({ $0 > 0 }).max() {
            return Measure(value: load, unit: exercise.unit, isLoad: true)
        }
        let amounts: [Decimal] = done.compactMap { set in
            switch exercise.unit {
            case .reps, .calories: set.reps.map { Decimal($0) }
            case .seconds, .minutes: set.seconds.map { Decimal($0) }
            case .meters: set.meters
            }
        }
        let best = exercise.lowerIsBetter == true ? amounts.min() : amounts.max()
        return best.map { Measure(value: $0, unit: exercise.unit, isLoad: false) }
    }

    /// "102,5 kg", "26 s", "2:10", "11,5 min", "2,45 m", "18 cal", "12".
    var text: String {
        if isLoad { return LoggedSet.format(value) + " kg" }
        switch unit {
        case .seconds where value >= 60:
            let seconds = NSDecimalNumber(decimal: value).intValue
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        default: return amount
        }
    }

    /// The difference never turns into minutes: "+8 s", "−0,5 min".
    /// `sign` is "+" or "−"; nil when equal ("=").
    func deltaText(sign: String?) -> String {
        guard let sign else { return "=" }
        return sign + (isLoad ? LoggedSet.format(value) + " kg" : amount)
    }

    private var amount: String {
        let number = LoggedSet.format(value)
        switch unit {
        case .reps: return number
        case .seconds: return number + " s"
        case .minutes: return LoggedSet.format(value / 60) + " min"
        case .meters: return number + " m"
        case .calories: return number + " cal"
        }
    }
}
