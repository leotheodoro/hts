import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

/// In-memory server with the API's rules: last write wins by updated_at, monotonic server cursor.
actor FakeSyncServer: SyncTransport {
    private var rows: [String: [String: (row: [String: JSONValue], written: Int)]] = [:]
    private var clock = 0
    private(set) var pushes = 0

    func push(_ changes: SyncChanges) async throws -> Int {
        pushes += 1
        var applied = 0
        for (table, incoming) in changes {
            for row in incoming {
                guard case .string(let id)? = row["id"], case .string(let updated)? = row["updated_at"] else {
                    continue
                }
                if let current = rows[table]?[id], case .string(let stored)? = current.row["updated_at"],
                    stored > updated
                {
                    continue
                }
                clock += 1
                rows[table, default: [:]][id] = (row, clock)
                applied += 1
            }
        }
        return applied
    }

    func pull(athleteId: UUID, since: String?) async throws -> (cursor: String?, changes: SyncChanges) {
        let after = since.flatMap(Int.init) ?? 0
        let owner = JSONValue.string(athleteId.uuidString.lowercased())
        var changes: SyncChanges = [:]
        var cursor = after
        for (table, byId) in rows {
            let fresh = byId.values.filter {
                $0.written > after && (table == "athlete" ? $0.row["id"] : $0.row["athlete_id"]) == owner
            }
            guard !fresh.isEmpty else { continue }
            changes[table] = fresh.map(\.row)
            cursor = max(cursor, fresh.map(\.written).max()!)
        }
        return (String(cursor), changes)
    }
}

@Suite struct SyncServiceTests {
    /// Device A with a plan and a finished session.
    func deviceA() async throws -> (AppDatabase, Athlete) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "募", weeks: 2, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Linha de Frente")]),
            athleteId: athlete.id, sagaId: saga.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [
            .init(
                kind: .strength, attributes: [.strength],
                exercises: [
                    .init(name: "Supino", setsText: "2", targetText: "6-6")
                ])
        ]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
        let sessions = SessionRepository(database)
        let session = try await sessions.start(filled, timeZone: TimeZone(identifier: "UTC")!)
        for var set in try await sessions.sets(sessionId: session.id) {
            set.weightKg = Decimal(string: "62.5")
            set.reps = 6
            set.completed = true
            try await sessions.save(set)
        }
        _ = try await sessions.finish(sessionId: session.id)
        return (database, athlete)
    }

    @Test func aNewDeviceRebuildsEverythingFromTheServer() async throws {
        let server = FakeSyncServer()
        let (a, athlete) = try await deviceA()
        let first = try await SyncService(a, transport: server).sync(athleteId: athlete.id)
        #expect(first.pushed == 10)  // athlete, saga, arc, template, block, exercise, prescription, session, 2 sets

        let b = try AppDatabase.inMemory()
        let pulled = try await SyncService(b, transport: server).sync(athleteId: athlete.id)
        #expect(pulled.pulled == 10)
        #expect(try await AthleteRepository(b).localAthlete()?.id == athlete.id)
        let (sessions, history) = try await ProgressService(b).history(athleteId: athlete.id)
        #expect(sessions.count == 1)
        #expect(history.sessions.first?.volumeKg == 750)
        let arc = try #require(try await PlanRepository(b).currentArc(athleteId: athlete.id))
        #expect(arc.kanji == "募")
        let plan = try #require(try await PlanRepository(b).plan(arcId: arc.id))
        #expect(plan.templates[0].blocks[0].exercises[0].prescription.targets == [.fixed(6), .fixed(6)])
        #expect(plan.templates[0].blocks[0].block.attributes == [.strength])
        let sets = try await SessionRepository(b).sets(sessionId: sessions[0].id)
        #expect(sets.allSatisfy { $0.completed && $0.weightKg == Decimal(string: "62.5") })
    }

    @Test func secondSyncOnlySendsWhatChangedAndEditsFlowBothWays() async throws {
        let server = FakeSyncServer()
        let (a, athlete) = try await deviceA()
        try await SyncService(a, transport: server).sync(athleteId: athlete.id)
        let b = try AppDatabase.inMemory()
        try await SyncService(b, transport: server).sync(athleteId: athlete.id)

        var renamed = try #require(try await AthleteRepository(b).localAthlete())
        renamed.displayName = "Leo B"
        try await AthleteRepository(b).update(renamed, now: .now.addingTimeInterval(5))
        let fromB = try await SyncService(b, transport: server).sync(athleteId: athlete.id)
        #expect(fromB.pushed >= 1)

        try await SyncService(a, transport: server).sync(athleteId: athlete.id)
        #expect(try await AthleteRepository(a).athlete(id: athlete.id)?.displayName == "Leo B")
    }

    @Test func anOlderRemoteRowDoesNotOverwriteANewerLocalOne() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Novo")
        var old = try await database.writer.read { db in
            SyncService.wire(try Row.fetchOne(db, sql: "SELECT * FROM athlete")!)
        }
        old["display_name"] = .string("Antigo")
        old["updated_at"] = .string("2020-01-01T00:00:00.000Z")
        _ = try await SyncService(database, transport: FakeSyncServer()).apply(["athlete": [old]])
        #expect(try await AthleteRepository(database).athlete(id: athlete.id)?.displayName == "Novo")
    }

    @Test func aDeviceOnlyPullsItsOwnAthlete() async throws {
        let server = FakeSyncServer()
        let (a, athleteA) = try await deviceA()
        try await SyncService(a, transport: server).sync(athleteId: athleteA.id)
        let (other, athleteB) = try await deviceA()
        try await SyncService(other, transport: server).sync(athleteId: athleteB.id)

        let fresh = try AppDatabase.inMemory()
        try await SyncService(fresh, transport: server).sync(athleteId: athleteA.id)
        let owners = try await fresh.writer.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT athlete_id FROM arc")
        }
        #expect(owners == [athleteA.id.uuidString.lowercased()])
    }
}
