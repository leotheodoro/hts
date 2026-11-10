import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

/// Monthly arcs in the database (#210): Base Performance with Adaptação, then Janeiro e Fevereiro, Novembro e
/// Dezembro and Outubro. Each arc has one template of Supino 3 × 8 for 1 week (one session completes it).
@Suite struct MonthlyArcServiceTests {
    /// Mid-month at noon, so the local calendar month does not depend on the time zone.
    static func day(_ month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 15, hour: 12))!
    }

    struct Fixture {
        let database: AppDatabase
        let athlete: Athlete
        let season: Season
        let arcs: [String: UUID]
    }

    func setUp() async throws -> Fixture {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let season = try await SeasonService(database).season(named: "Base Performance", athleteId: athlete.id)
        var ids: [String: UUID] = [:]
        for (name, months) in [
            ("Adaptação", nil), ("Janeiro e Fevereiro", [1, 2]), ("Novembro e Dezembro", [11, 12]),
            ("Outubro", [10]),
        ] as [(String, [Int]?)] {
            let arc = try await ArcService(database).save(
                ArcDraft(
                    name: name, kanji: "試", weeks: 1, startDate: LocalDate("2026-01-01")!,
                    templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: season.id)
            let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
            var draft = try #require(
                try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
            draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
            try await TemplateService(database).save(draft)
            if let months {
                let json = String(data: try JSONEncoder().encode(months), encoding: .utf8)!
                try await database.writer.write { db in
                    try db.execute(sql: "UPDATE arc SET months = ? WHERE id = ?", arguments: [json, arc.id.sql])
                }
            }
            ids[name] = arc.id
        }
        return Fixture(database: database, athlete: athlete, season: season, arcs: ids)
    }

    func finishOneSession(_ f: Fixture, arc: String, now: Date) async throws -> Arc? {
        let arcId = try #require(f.arcs[arc])
        let plan = try #require(try await PlanRepository(f.database).plan(arcId: arcId))
        let sessions = SessionRepository(f.database)
        let session = try await sessions.start(plan.templates[0], now: now)
        _ = try await sessions.finish(sessionId: session.id, now: now)
        return try await ArcService(f.database).completeIfDone(arcId: arcId, now: now)
    }

    func current(_ f: Fixture) async throws -> String? {
        try await PlanRepository(f.database).currentArc(athleteId: f.athlete.id)?.name
    }

    @Test func monthsAreLockedWhileTheInitialArcIsOpen() async throws {
        let f = try await setUp()
        #expect(try await current(f) == "Adaptação")
        let summaries = try await ArcService(f.database).summaries(athleteId: f.athlete.id, seasonId: f.season.id)
        #expect(summaries.filter(\.isOpen).isEmpty)
        #expect(try await ArcService(f.database).canTrain(arcId: f.arcs["Outubro"]!) == false)
        #expect(try await ArcService(f.database).canTrain(arcId: f.arcs["Adaptação"]!) == true)
    }

    /// In November the arc of November becomes current, and every month opens.
    @Test func finishingTheInitialArcOpensEveryMonth() async throws {
        let f = try await setUp()
        let next = try await finishOneSession(f, arc: "Adaptação", now: Self.day(11))
        #expect(next?.name == "Novembro e Dezembro")
        #expect(try await current(f) == "Novembro e Dezembro")
        let summaries = try await ArcService(f.database).summaries(athleteId: f.athlete.id, seasonId: f.season.id)
        // The current one shows ATUAL; the other open months, Disponível.
        #expect(summaries.filter(\.isOpen).map(\.arc.name) == ["Janeiro e Fevereiro", "Outubro"])
        #expect(try await ArcService(f.database).canTrain(arcId: f.arcs["Outubro"]!) == true)
    }

    /// A new month moves the current arc; the arcs keep their counts.
    @Test func theCurrentArcFollowsTheCalendar() async throws {
        let f = try await setUp()
        _ = try await finishOneSession(f, arc: "Adaptação", now: Self.day(11))
        try await SeasonService(f.database).alignMonthlyArc(athleteId: f.athlete.id, now: Self.day(1))
        #expect(try await current(f) == "Janeiro e Fevereiro")
        try await SeasonService(f.database).alignMonthlyArc(athleteId: f.athlete.id, now: Self.day(1))
        #expect(try await current(f) == "Janeiro e Fevereiro")
    }

    /// Before the monthly phase the calendar changes nothing.
    @Test func alignmentLeavesTheInitialArcAlone() async throws {
        let f = try await setUp()
        try await SeasonService(f.database).alignMonthlyArc(athleteId: f.athlete.id, now: Self.day(10))
        #expect(try await current(f) == "Adaptação")
    }

    /// A month trained out of its calendar month still completes; the current arc stays on the calendar.
    @Test func anOpenMonthThatIsNotCurrentCompletes() async throws {
        let f = try await setUp()
        _ = try await finishOneSession(f, arc: "Adaptação", now: Self.day(11))
        _ = try await finishOneSession(f, arc: "Outubro", now: Self.day(11))
        let summaries = try await ArcService(f.database).summaries(athleteId: f.athlete.id, seasonId: f.season.id)
        #expect(summaries.first { $0.arc.name == "Outubro" }?.arc.status == .completed)
        #expect(try await current(f) == "Novembro e Dezembro")
    }

    /// Finishing the month of the calendar hands the current slot to the first open month.
    @Test func finishingTheCurrentMonthMovesToTheFirstOpenOne() async throws {
        let f = try await setUp()
        _ = try await finishOneSession(f, arc: "Adaptação", now: Self.day(11))
        let next = try await finishOneSession(f, arc: "Novembro e Dezembro", now: Self.day(11))
        #expect(next?.name == "Janeiro e Fevereiro")
    }

    /// Reactivating a season in its monthly phase lands on the calendar month.
    @Test func activatingASeasonInItsMonthlyPhaseLandsOnTheCalendarMonth() async throws {
        let f = try await setUp()
        _ = try await finishOneSession(f, arc: "Adaptação", now: Self.day(11))
        let seasons = SeasonService(f.database)
        let other = try await seasons.season(named: "Jiu-Jitsu", athleteId: f.athlete.id)
        try await seasons.activate(seasonId: other.id, athleteId: f.athlete.id, now: Self.day(11))
        #expect(try await current(f) == nil)
        try await seasons.activate(seasonId: f.season.id, athleteId: f.athlete.id, now: Self.day(10))
        #expect(try await current(f) == "Outubro")
    }

    /// The months travel through the record and sync as JSON.
    @Test func monthsRoundTrip() async throws {
        let f = try await setUp()
        let arc = try await f.database.writer.read { db in try Arc.fetchOne(db, key: f.arcs["Novembro e Dezembro"]!) }
        #expect(arc?.months == [11, 12])
        #expect(arc?.isMonthly == true)
    }
}
