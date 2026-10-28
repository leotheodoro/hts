import Foundation

/// Rest between sets. It keeps the end instant, not a countdown, so it stays right in the background, after the
/// app is killed and with the screen locked (docs/product/handoff-produto.md, Timer de descanso).
public struct RestTimer: Hashable, Sendable, Codable {
    public static let step: TimeInterval = 15

    public private(set) var startedAt: Date
    public private(set) var endsAt: Date

    public init(startedAt: Date, seconds: Int) {
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(TimeInterval(max(seconds, 0)))
    }

    /// The exercise's own rest wins over the athlete's default.
    public static func seconds(exerciseRest: Int?, athleteDefault: Int) -> Int {
        exerciseRest ?? athleteDefault
    }

    public var duration: TimeInterval { endsAt.timeIntervalSince(startedAt) }

    public func remaining(at now: Date) -> TimeInterval {
        max(endsAt.timeIntervalSince(now), 0)
    }

    public func isFinished(at now: Date) -> Bool { remaining(at: now) == 0 }

    /// Elapsed share of the rest, 0 to 1, for the bar.
    public func progress(at now: Date) -> Double {
        duration > 0 ? min(max(now.timeIntervalSince(startedAt) / duration, 0), 1) : 1
    }

    /// −15 s / +15 s. Never ends before `now`.
    public mutating func adjust(by seconds: TimeInterval, now: Date) {
        endsAt = max(endsAt.addingTimeInterval(seconds), now)
    }

    /// "1:12".
    public static func format(_ remaining: TimeInterval) -> String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// When a checked set starts the rest (docs/product/handoff-produto.md, Combo).
public enum RestPolicy {
    /// In a combo the exercises go in sequence and the rest comes after the last one; elsewhere every set rests.
    public static func startsRest(blockKind: BlockKind, exerciseIndex: Int, exerciseCount: Int) -> Bool {
        switch blockKind {
        case .combo, .chainedCombo: exerciseIndex == exerciseCount - 1
        case .fightRound: false
        default: true
        }
    }
}
