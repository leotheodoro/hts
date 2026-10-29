import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

/// A migrated in-memory database with one athlete and one season.
struct PlanFixture {
    let database: AppDatabase
    let athlete: Athlete
    let season: Season
    let now = Date(timeIntervalSince1970: 1_761_658_260.123)

    init() async throws {
        database = try AppDatabase.inMemory()
        athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        season = Season(
            id: UUIDv7.make(), athleteId: athlete.id, name: "Jiu-Jitsu", position: 0, active: true, createdAt: now)
        try await PlanRepository(database).save(season)
    }

    func arc(_ name: String, status: ArcStatus = .queued, position: Int = 0) -> Arc {
        Arc(
            id: UUIDv7.make(), athleteId: athlete.id, seasonId: season.id, name: name, weeks: 2,
            startDate: LocalDate("2026-11-02"), status: status, position: position, createdAt: now)
    }

    /// Arc → template A → strength block → Zercher Squat 4 × 6-6-3-3.
    func seedPlan(arc: Arc) async throws -> (WorkoutTemplate, Exercise) {
        let repository = PlanRepository(database)
        let template = WorkoutTemplate(
            id: UUIDv7.make(), athleteId: athlete.id, arcId: arc.id, letter: "A", name: "Linha de Frente",
            position: 0, createdAt: now)
        let block = Block(
            id: UUIDv7.make(), athleteId: athlete.id, workoutTemplateId: template.id, kind: .strength,
            attributes: [.strength], position: 0, createdAt: now)
        let exercise = try await ExerciseCatalog(database).findOrCreate(
            name: "Zercher Squat", athleteId: athlete.id, defaultAttribute: .strength, now: now)
        let prescription = PrescribedExercise(
            id: UUIDv7.make(), athleteId: athlete.id, blockId: block.id, exerciseId: exercise.id, setsMin: 4,
            targets: [.fixed(6), .fixed(6), .fixed(3), .fixed(3)], restSeconds: 120, position: 0, createdAt: now)
        try await repository.saveAll([arc, template, block, prescription])
        return (template, exercise)
    }
}

@Suite struct SchemaParityTests {
    struct Snapshot: Decodable {
        struct Table: Decodable {
            let name: String
            let columns: [ColumnInfo]
        }
        struct ColumnInfo: Decodable, Hashable {
            let name: String
            let notNull: Bool
        }
        let tables: [Table]
    }

    /// packages/contracts/db-schema.json is exported from the Drizzle schema by `pnpm sync:shared`.
    @Test func sqliteMirrorsPostgresColumnNamesAndNullability() throws {
        let url = try #require(
            Bundle.module.url(forResource: "db-schema", withExtension: "json", subdirectory: "Resources"))
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        let database = try AppDatabase.inMemory()
        let sqliteTables = try database.writer.read { db in
            try String.fetchAll(
                db,
                sql:
                    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'grdb_%' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'local_%'"
            )
        }
        #expect(Set(sqliteTables) == Set(snapshot.tables.map(\.name)))
        for table in snapshot.tables {
            let columns = try database.writer.read { db in try db.columns(in: table.name) }
            let sqlite = Set(
                columns.map { Snapshot.ColumnInfo(name: $0.name, notNull: $0.isNotNull || $0.primaryKeyIndex > 0) })
            #expect(sqlite == Set(table.columns), "table \(table.name)")
        }
    }
}

@Suite struct PlanRepositoryTests {
    @Test func storesAndReadsAFullPlan() async throws {
        let fixture = try await PlanFixture()
        let arc = fixture.arc("Recrutamento", status: .current)
        let (template, exercise) = try await fixture.seedPlan(arc: arc)

        let plan = try #require(try await PlanRepository(fixture.database).plan(arcId: arc.id))
        #expect(plan.arc == arc)
        #expect(plan.templates.map(\.template) == [template])
        let planned = try #require(plan.templates.first?.blocks.first?.exercises.first)
        #expect(planned.exercise == exercise)
        #expect(planned.prescription.targets == [.fixed(6), .fixed(6), .fixed(3), .fixed(3)])
        #expect(planned.prescription.isValid)
        #expect(try await PlanRepository(fixture.database).currentArc(athleteId: fixture.athlete.id) == arc)
    }

    @Test func readsOneTemplateWithItsArc() async throws {
        let fixture = try await PlanFixture()
        let arc = fixture.arc("Recrutamento", status: .current)
        let (template, exercise) = try await fixture.seedPlan(arc: arc)
        let repository = PlanRepository(fixture.database)
        let found = try #require(try await repository.template(id: template.id))
        #expect(found.arc == arc)
        #expect(found.plan.template == template)
        #expect(found.plan.blocks.first?.exercises.first?.exercise == exercise)

        var deleted = template
        deleted.deletedAt = fixture.now
        try await repository.save(deleted)
        #expect(try await repository.template(id: template.id) == nil)
    }

    @Test func storesDatesAndJSONInThePostgresFormats() async throws {
        let fixture = try await PlanFixture()
        let arc = fixture.arc("Recrutamento")
        _ = try await fixture.seedPlan(arc: arc)
        let stored = try await fixture.database.writer.read { db in
            [
                try String.fetchOne(db, sql: "SELECT start_date FROM arc"),
                try String.fetchOne(db, sql: "SELECT attributes FROM block"),
                try String.fetchOne(db, sql: "SELECT targets FROM prescribed_exercise"),
                try String.fetchOne(db, sql: "SELECT created_at FROM arc"),
            ]
        }
        #expect(stored[0] == "2026-11-02")
        #expect(stored[1] == #"["strength"]"#)
        #expect(stored[2]?.contains(#""type":"fixed""#) == true)
        #expect(stored[3] == "2025-10-28T13:31:00.123Z")
    }

    @Test func allowsOnlyOneCurrentArc() async throws {
        let fixture = try await PlanFixture()
        let repository = PlanRepository(fixture.database)
        try await repository.save(fixture.arc("I", status: .current))
        await #expect(throws: DatabaseError.self) {
            try await repository.save(fixture.arc("II", status: .current, position: 1))
        }
    }

    @Test func rejectsUnknownEnumValues() async throws {
        let fixture = try await PlanFixture()
        await #expect(throws: DatabaseError.self) {
            try await fixture.database.writer.write { db in
                try db.execute(
                    sql:
                        "UPDATE season SET name = name; INSERT INTO arc (id, athlete_id, season_id, name, kind, status, position, created_at, updated_at) VALUES ('x', ?, ?, 'X', 'weird', 'queued', 0, '', '')",
                    arguments: [fixture.athlete.id.uuidString.lowercased(), fixture.season.id.uuidString.lowercased()])
            }
        }
    }

    @Test func listsArcsInPositionOrderWithoutDeletedOnes() async throws {
        let fixture = try await PlanFixture()
        let repository = PlanRepository(fixture.database)
        var deleted = fixture.arc("Apagado", position: 0)
        deleted.deletedAt = fixture.now
        let second = fixture.arc("Forja", position: 2)
        let first = fixture.arc("Recrutamento", position: 1)
        try await repository.saveAll([deleted, second, first])
        let names = try await repository.arcs(athleteId: fixture.athlete.id, seasonId: fixture.season.id).map(\.name)
        #expect(names == ["Recrutamento", "Forja"])
    }

    @Test func copyingATemplateIsDeepAndIndependent() async throws {
        let fixture = try await PlanFixture()
        let repository = PlanRepository(fixture.database)
        let source = fixture.arc("Recrutamento", position: 0)
        let target = fixture.arc("Forja", position: 1)
        let (template, _) = try await fixture.seedPlan(arc: source)
        try await repository.save(target)

        let copy = try await repository.copyTemplate(id: template.id, toArc: target.id, letter: "B", position: 0)
        #expect(copy.sourceTemplateId == template.id)
        #expect(copy.id != template.id)

        // Editing the copy's prescription leaves the original untouched.
        let copiedPlan = try #require(try await repository.plan(arcId: target.id))
        var copiedPrescription = try #require(copiedPlan.templates.first?.blocks.first?.exercises.first?.prescription)
        copiedPrescription.targets = [.fixed(10)]
        try await repository.save(copiedPrescription)

        let originalPlan = try #require(try await repository.plan(arcId: source.id))
        let original = try #require(originalPlan.templates.first?.blocks.first?.exercises.first?.prescription)
        #expect(original.targets == [.fixed(6), .fixed(6), .fixed(3), .fixed(3)])
        #expect(original.id != copiedPrescription.id)
    }
}

@Suite struct ExerciseCatalogTests {
    @Test func findOrCreateReusesTheNormalizedName() async throws {
        let fixture = try await PlanFixture()
        let catalog = ExerciseCatalog(fixture.database)
        let first = try await catalog.findOrCreate(name: "Barra Fixa", athleteId: fixture.athlete.id)
        let again = try await catalog.findOrCreate(name: "  barra   fíxa ", athleteId: fixture.athlete.id)
        #expect(again == first)
        #expect(first.name == "Barra Fixa")
    }

    @Test func aDeletedExerciseFreesItsName() async throws {
        let fixture = try await PlanFixture()
        let catalog = ExerciseCatalog(fixture.database)
        var old = try await catalog.findOrCreate(name: "Barra Fixa", athleteId: fixture.athlete.id)
        old.deletedAt = fixture.now
        try await PlanRepository(fixture.database).save(old)
        let new = try await catalog.findOrCreate(name: "Barra fixa", athleteId: fixture.athlete.id)
        #expect(new.id != old.id)
    }

    @Test func searchFindsPrefixMatchesFirst() async throws {
        let fixture = try await PlanFixture()
        let catalog = ExerciseCatalog(fixture.database)
        for name in ["Remada Curvada", "Barra Fixa", "Agachamento com Barra"] {
            _ = try await catalog.findOrCreate(name: name, athleteId: fixture.athlete.id)
        }
        let names = try await catalog.search("barra", athleteId: fixture.athlete.id).map(\.name)
        #expect(names == ["Barra Fixa", "Agachamento com Barra"])
    }
}

@Suite struct BattleRepositoryTests {
    @Test func currentIsTheNextOneOrTheLastWithoutResult() async throws {
        let fixture = try await PlanFixture()
        let repository = BattleRepository(fixture.database)
        let past = Battle(
            id: UUIDv7.make(), athleteId: fixture.athlete.id, seasonId: fixture.season.id, name: "Copa A",
            date: LocalDate("2026-10-10")!, createdAt: fixture.now)
        try await repository.save(past)
        #expect(
            try await repository.current(athleteId: fixture.athlete.id, today: LocalDate("2026-11-01")!)?.id == past.id)

        var withResult = past
        withResult.result = .gold
        try await repository.save(withResult)
        #expect(try await repository.current(athleteId: fixture.athlete.id, today: LocalDate("2026-11-01")!) == nil)

        let next = Battle(
            id: UUIDv7.make(), athleteId: fixture.athlete.id, seasonId: fixture.season.id, name: "Copa B",
            date: LocalDate("2026-12-12")!, createdAt: fixture.now)
        try await repository.save(next)
        #expect(
            try await repository.current(athleteId: fixture.athlete.id, today: LocalDate("2026-11-01")!)?.id == next.id)
    }
}
