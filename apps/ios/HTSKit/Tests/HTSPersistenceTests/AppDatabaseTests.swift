import Foundation
import GRDB
import Testing

@testable import HTSPersistence

@Suite struct MigrationTests {
    @Test func createsAthleteTableMirroringPostgres() throws {
        let database = try AppDatabase.inMemory()
        let columns = try database.writer.read { db in try db.columns(in: "athlete") }
        #expect(
            columns.map(\.name) == [
                "id", "display_name", "default_rest_seconds", "created_at", "updated_at", "deleted_at",
            ])
        #expect(columns.first { $0.name == "default_rest_seconds" }?.defaultValueSQL == "90")
        #expect(columns.filter(\.isNotNull).map(\.name).contains("deleted_at") == false)
    }

    @Test func defaultRestIs90Seconds() throws {
        let database = try AppDatabase.inMemory()
        let rest = try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO athlete (id, display_name, created_at, updated_at)
                    VALUES ('0190f2c4-0000-7000-8000-000000000000', 'Leo', '2026-10-28T13:00:00.000Z', '2026-10-28T13:00:00.000Z')
                    """)
            return try Int.fetchOne(db, sql: "SELECT default_rest_seconds FROM athlete")
        }
        #expect(rest == 90)
    }
}

@Suite struct AthleteRepositoryTests {
    @Test func createsTheLocalAthleteOnlyOnce() async throws {
        let repository = AthleteRepository(try AppDatabase.inMemory())
        let first = try await repository.ensureLocalAthlete(displayName: "Atleta")
        let second = try await repository.ensureLocalAthlete(displayName: "Outro nome")
        #expect(first == second)
        #expect(first.defaultRestSeconds == 90)
        #expect(try await repository.localAthlete() == first)
    }

    @Test func storesUUIDsAndDatesAsTextLikePostgres() async throws {
        let database = try AppDatabase.inMemory()
        let now = try Date(
            "2026-10-28T13:31:00.123Z", strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo", now: now)
        let stored = try await database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT id, created_at FROM athlete").map {
                [$0["id"] as String, $0["created_at"] as String]
            }
        }
        #expect(stored == [athlete.id.uuidString.lowercased(), "2026-10-28T13:31:00.123Z"])
        #expect(try await AthleteRepository(database).athlete(id: athlete.id) == athlete)
    }

    @Test func ignoresSoftDeletedAthletes() async throws {
        let database = try AppDatabase.inMemory()
        let repository = AthleteRepository(database)
        let deleted = Athlete(displayName: "Antigo", deletedAt: .now)
        try await database.writer.write { db in try deleted.insert(db) }
        #expect(try await repository.athlete(id: deleted.id) == nil)
        let local = try await repository.ensureLocalAthlete(displayName: "Leo")
        #expect(local.id != deleted.id)
    }
}

@Suite struct UUIDv7Tests {
    @Test func setsVersionAndVariant() {
        let uuid = UUIDv7.make().uuid
        #expect(uuid.6 >> 4 == 0x7)
        #expect(uuid.8 >> 6 == 0b10)
    }

    @Test func encodesUnixMilliseconds() {
        let date = Date(timeIntervalSince1970: 1_761_658_260.123)
        let hex = UUIDv7.make(at: date).uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        #expect(UInt64(hex, radix: 16) == 1_761_658_260_123)
    }

    @Test func sortsByCreationTime() {
        let earlier = UUIDv7.make(at: Date(timeIntervalSince1970: 1_000))
        let later = UUIDv7.make(at: Date(timeIntervalSince1970: 1_001))
        #expect(earlier.uuidString.lowercased() < later.uuidString.lowercased())
    }
}
