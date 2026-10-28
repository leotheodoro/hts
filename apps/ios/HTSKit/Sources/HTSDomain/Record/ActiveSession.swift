import Foundation

extension ArcSchedule {
    /// The template to do next: the rotation A, B, C… after the last one done in the arc, or A to start.
    public func next(after lastLetter: String?) -> String? {
        guard !letters.isEmpty else { return nil }
        guard let lastLetter, let index = letters.firstIndex(of: lastLetter) else { return letters[0] }
        return letters[(index + 1) % letters.count]
    }
}

/// Rules of the set table in the active workout (docs/product/handoff-produto.md, Execução do treino).
public enum SetRules {
    /// Value to show and save for an empty field when the set is checked: the target of that set for reps,
    /// seconds or meters (the low end of a range; nil for "máx").
    public static func defaultAmount(for target: SetTarget?) -> Decimal? {
        switch target {
        case .fixed(let value)?: Decimal(value)
        case .range(let min, _)?: Decimal(min)
        case .max?, nil: nil
        }
    }

    /// Checking a set: it becomes completed, and empty fields take the target and the previous load.
    public static func check(
        _ set: LoggedSet, unit: ExerciseUnit, target: SetTarget?, previous: LoggedSet?, at now: Date
    ) -> LoggedSet {
        var set = set
        set.completed = true
        set.completedAt = now.roundedToMilliseconds
        set.updatedAt = now.roundedToMilliseconds
        if set.weightKg == nil { set.weightKg = previous?.weightKg }
        let amount = defaultAmount(for: target)
        switch unit {
        case .reps where set.reps == nil:
            set.reps = amount.map { NSDecimalNumber(decimal: $0).intValue } ?? previous?.reps
        case .seconds where set.seconds == nil:
            set.seconds = amount.map { NSDecimalNumber(decimal: $0).intValue } ?? previous?.seconds
        case .minutes where set.seconds == nil:
            set.seconds = amount.map { NSDecimalNumber(decimal: $0 * 60).intValue } ?? previous?.seconds
        case .meters where set.meters == nil:
            set.meters = amount ?? previous?.meters
        default:
            break
        }
        return set
    }

    public static func uncheck(_ set: LoggedSet, at now: Date) -> LoggedSet {
        var set = set
        set.completed = false
        set.completedAt = nil
        set.updatedAt = now.roundedToMilliseconds
        return set
    }
}

extension LoggedSet {
    /// "60 × 6", "40 s", "1,5 min", "400 m" — the "Anterior" column.
    public func summary(unit: ExerciseUnit) -> String? {
        let kg = weightKg.map { Self.format($0) }
        let amount: String?
        switch unit {
        case .reps: amount = reps.map(String.init)
        case .seconds: amount = seconds.map { "\($0) s" }
        case .minutes: amount = seconds.map { Self.format(Decimal($0) / 60) + " min" }
        case .meters: amount = meters.map { Self.format($0) + " m" }
        }
        switch (kg, amount) {
        case let (kg?, amount?): return "\(kg) × \(amount)"
        case let (nil, amount?): return amount
        case let (kg?, nil): return "\(kg) kg"
        case (nil, nil): return nil
        }
    }

    /// "62,5", "60": comma decimals as in pt-BR, no trailing zeros.
    public static func format(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue.replacingOccurrences(of: ".", with: ",")
    }
}
