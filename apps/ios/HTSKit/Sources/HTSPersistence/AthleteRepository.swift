import Foundation
import GRDB

public struct AthleteRepository: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// The athlete on this device, created on first launch. Today the app has a single local athlete.
    public func ensureLocalAthlete(displayName: String, now: Date = .now) async throws -> Athlete {
        try await database.writer.write { db in
            if let existing = try Self.localAthleteRequest.fetchOne(db) {
                return existing
            }
            let athlete = Athlete(displayName: displayName, createdAt: now)
            try athlete.insert(db)
            return athlete
        }
    }

    /// Saves edited settings (name, default rest).
    @discardableResult
    public func update(_ athlete: Athlete, now: Date = .now) async throws -> Athlete {
        var athlete = athlete
        athlete.displayName = athlete.displayName.trimmingCharacters(in: .whitespaces)
        athlete.updatedAt = now.roundedToMilliseconds
        try await database.writer.write { [athlete] db in try athlete.update(db) }
        return athlete
    }

    public func localAthlete() async throws -> Athlete? {
        try await database.writer.read { db in try Self.localAthleteRequest.fetchOne(db) }
    }

    public func athlete(id: UUID) async throws -> Athlete? {
        try await database.writer.read { db in
            try Athlete.filter(key: id).filter(Columns.deletedAt == nil).fetchOne(db)
        }
    }

    private static var localAthleteRequest: QueryInterfaceRequest<Athlete> {
        Athlete.filter(Columns.deletedAt == nil).order(Columns.createdAt)
    }
}
