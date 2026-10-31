import Foundation

/// An activity recorded on another platform (Garmin) that reached the athlete through the API (docs/decisions/0033).
/// Born on the server and read-only on the device. XP, attributes and the link to an HTS workout are derived.
public struct ImportedActivity: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var athleteId: UUID
    /// "garmin".
    public var source: String
    public var externalId: String
    /// The platform's type, as sent ("RUNNING").
    public var activityType: String
    public var name: String?
    public var startedAt: Date
    public var durationSeconds: Int
    public var distanceMeters: Decimal?
    public var averageHeartRate: Int?
    public var calories: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, source: String, externalId: String, activityType: String, name: String? = nil,
        startedAt: Date, durationSeconds: Int, distanceMeters: Decimal? = nil, averageHeartRate: Int? = nil,
        calories: Int? = nil, createdAt: Date, updatedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.source = source
        self.externalId = externalId
        self.activityType = activityType
        self.name = name
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.calories = calories
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.deletedAt = deletedAt
    }

    /// When it ended.
    public var finishedAt: Date { startedAt.addingTimeInterval(TimeInterval(durationSeconds)) }
}
