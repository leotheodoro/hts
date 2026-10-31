import Foundation

/// An imported activity (Garmin) as progress sees it. Mirrors `HistoryActivity` in packages/progression. Linked
/// ones overlap an HTS workout and give no XP of their own.
public struct HistoryActivity: Hashable, Sendable, Decodable {
    public let activityType: String
    public let durationSeconds: Int
    public let linked: Bool

    public init(activityType: String, durationSeconds: Int, linked: Bool) {
        self.activityType = activityType
        self.durationSeconds = durationSeconds
        self.linked = linked
    }
}

/// What an activity gives. Mirrors `ActivityXp`.
public struct ActivityXP: Hashable, Sendable, Decodable {
    /// Whole minutes that count, up to the cap.
    public let minutes: Int
    public let xp: Int
    /// XP each of `attributes` gets.
    public let attributeXP: Int
    public let attributes: [Attribute]

    private enum CodingKeys: String, CodingKey {
        case minutes, xp, attributes
        case attributeXP = "attributeXp"
    }

    public init(minutes: Int, xp: Int, attributeXP: Int, attributes: [Attribute]) {
        self.minutes = minutes
        self.xp = xp
        self.attributeXP = attributeXP
        self.attributes = attributes
    }
}

/// The attribute XP of one activity, as `attributeLevels` adds it.
public struct ActivityAttributeXP: Hashable, Sendable, Decodable {
    public let attributes: [Attribute]
    public let attributeXP: Int

    private enum CodingKeys: String, CodingKey {
        case attributes
        case attributeXP = "attributeXp"
    }

    public init(attributes: [Attribute], attributeXP: Int) {
        self.attributes = attributes
        self.attributeXP = attributeXP
    }
}

extension Progression {
    /// Only time counts, up to `maxMinutes`; each attribute of the type gets `attributeXp` every
    /// `minutesPerAttributeXp` minutes, rounded half up. Must match `activityXp` in packages/progression; both run
    /// packages/fixtures/activity-xp.json.
    public func activityXP(activityType: String, durationSeconds: Int) -> ActivityXP {
        let rules = rules.activity
        let minutes = min(max(durationSeconds, 0) / 60, rules.maxMinutes)
        let attributeXP = (Double(minutes * rules.attributeXp) / Double(rules.minutesPerAttributeXp)).rounded()
        return ActivityXP(
            minutes: minutes, xp: minutes * rules.xpPerMinute, attributeXP: Int(attributeXP),
            attributes: rules.attributes[activityType] ?? [])
    }

    /// Linked when the activity overlaps HTS workouts for more than half of its duration (spec 2026-10-31).
    /// Workouts do not overlap each other. Must match `isActivityLinked`; both run activity-link.json.
    public func isActivityLinked(
        startedAt: Date, durationSeconds: Int, sessions: [(startedAt: Date, finishedAt: Date)]
    ) -> Bool {
        guard durationSeconds > 0 else { return false }
        let end = startedAt.addingTimeInterval(TimeInterval(durationSeconds))
        var overlap: TimeInterval = 0
        for session in sessions {
            let from = max(startedAt, session.startedAt)
            let to = min(end, session.finishedAt)
            if to > from { overlap += to.timeIntervalSince(from) }
        }
        return 2 * overlap > TimeInterval(durationSeconds)
    }
}
