import Foundation

/// A pause of an arc (docs/decisions/0038): `startDate` the day it was paused, `endDate` the day it was resumed
/// (nil while paused). Mirrors `arc_pause` in the API.
public struct ArcPause: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var athleteId: UUID
    public var arcId: UUID
    public var startDate: LocalDate
    public var endDate: LocalDate?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, arcId: UUID, startDate: LocalDate, endDate: LocalDate?, createdAt: Date,
        updatedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.arcId = arcId
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt.roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }

    public var interval: PauseInterval { PauseInterval(startDate: startDate, endDate: endDate) }
}
