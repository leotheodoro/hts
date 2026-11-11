import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

/// Treino teste (#216): a season with Adaptação (current) and Força (locked). Each arc has a test, then A and B
/// (Supino 3 × 8), for 1 week.
@Suite struct TestWorkoutTests {
    struct Fixture {
        let database: AppDatabase
        let athlete: Athlete
        let season: Season
        /// Arc name to its templates, by name ("Teste", "A", "B").
        let templates: [String: [String: TemplatePlan]]
        let arcs: [String: UUID]
    }

    func setUp() async throws -> Fixture {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let season = try await SeasonService(database).season(named: "Base Performance", athleteId: athlete.id)
        var templates: [String: [String: TemplatePlan]] = [:]
        var arcs: [String: UUID] = [:]
        for name in ["Adaptação", "Força"] {
            let arc = try await ArcService(database).save(
                ArcDraft(
                    name: name, kanji: "試", weeks: 1, startDate: LocalDate("2026-01-01")!,
                    templates: ["Teste", "A", "B"].map { .init(origin: .new, name: $0) }),
                athleteId: athlete.id, seasonId: season.id)
            let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
            for template in plan.templates {
                var draft = try #require(try await TemplateService(database).draft(templateId: template.template.id))
                draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
                try await TemplateService(database).save(draft)
            }
            try await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE workout_template SET is_test = 1 WHERE arc_id = ? AND name = 'Teste'",
                    arguments: [arc.id.sql])
            }
            let reloaded = try #require(try await PlanRepository(database).plan(arcId: arc.id))
            templates[name] = Dictionary(uniqueKeysWithValues: reloaded.templates.map { ($0.template.name, $0) })
            arcs[name] = arc.id
        }
        return Fixture(database: database, athlete: athlete, season: season, templates: templates, arcs: arcs)
    }

    func train(_ f: Fixture, _ arc: String, _ template: String, seconds: Int? = nil, at now: Date = .now)
        async throws -> Session
    {
        let plan = try #require(f.templates[arc]?[template])
        let sessions = SessionRepository(f.database)
        let session = try await sessions.start(plan, now: now)
        if let seconds {
            var set = try #require(try await sessions.sets(sessionId: session.id).first)
            set.reps = seconds
            set.completed = true
            try await sessions.save(set)
        }
        _ = try await sessions.finish(sessionId: session.id, now: now)
        _ = try await ArcService(f.database).completeIfDone(arcId: session.arcId, now: now)
        return session
    }

    @Test func theFlagIsReadBack() async throws {
        let f = try await setUp()
        #expect(f.templates["Adaptação"]?["Teste"]?.template.isTest == true)
        #expect(f.templates["Adaptação"]?["A"]?.template.isTest == false)
    }

    /// A test opens in a locked arc too; the other workouts of that arc stay locked.
    @Test func aTestCanAlwaysStart() async throws {
        let f = try await setUp()
        let service = ArcService(f.database)
        let lockedTest = try #require(f.templates["Força"]?["Teste"]?.template.id)
        let lockedA = try #require(f.templates["Força"]?["A"]?.template.id)
        #expect(try await service.canTrain(templateId: lockedTest))
        #expect(try await service.canTrain(templateId: lockedA) == false)
    }

    /// The test is outside the rotation: two workouts a week, and its sessions neither count nor complete the arc.
    @Test func aTestIsOutsideTheCount() async throws {
        let f = try await setUp()
        _ = try await train(f, "Adaptação", "Teste")
        let summaries = try await ArcService(f.database).summaries(athleteId: f.athlete.id, seasonId: f.season.id)
        let adaptation = try #require(summaries.first)
        #expect(adaptation.schedule.weeklyGoal == 2)
        #expect(adaptation.completedSessions == 0)

        _ = try await train(f, "Adaptação", "A")
        _ = try await train(f, "Adaptação", "Teste")
        let plan = try #require(try await PlanRepository(f.database).plan(arcId: f.arcs["Adaptação"]!))
        #expect(ArcSchedule(plan).letters == ["B", "C"])
        // The rotation goes on from A: the test in between does not reset it.
        let last = try await SessionRepository(f.database).lastLetter(arcId: f.arcs["Adaptação"]!)
        #expect(ArcSchedule(plan).next(after: last) == "C")

        _ = try await train(f, "Adaptação", "B")
        let current = try await PlanRepository(f.database).currentArc(athleteId: f.athlete.id)
        #expect(current?.name == "Força")
    }

    /// The runs of a test, newest first, with their sets, for EVOLUÇÃO.
    @Test func runsOfATest() async throws {
        let f = try await setUp()
        let day = { (d: Int) in Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: d, hour: 12))! }
        _ = try await train(f, "Adaptação", "Teste", seconds: 6, at: day(1))
        _ = try await train(f, "Adaptação", "A", seconds: 99, at: day(2))
        _ = try await train(f, "Adaptação", "Teste", seconds: 8, at: day(3))
        _ = try await train(f, "Adaptação", "Teste", seconds: 10, at: day(5))
        let test = try #require(f.templates["Adaptação"]?["Teste"]?.template.id)
        let runs = try await SessionRepository(f.database).testRuns(templateId: test, limit: 2)
        #expect(runs.map(\.date) == [LocalDate("2026-10-05")!, LocalDate("2026-10-03")!])
        #expect(runs.map { $0.sets.compactMap(\.reps) } == [[10], [8]])
        #expect(runs.first?.exercises.map(\.name) == ["Supino"])
        let evolution = try #require(TestEvolution(runs: runs))
        #expect(evolution.rows.first?.delta == "+2")
    }
}
