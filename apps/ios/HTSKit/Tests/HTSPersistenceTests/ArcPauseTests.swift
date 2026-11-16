import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

/// Pausing the current arc (#222, docs/decisions/0038).
@Suite struct ArcPauseTests {
    /// Noon of a calendar day in the device time zone, where the app reads the dates of a pause.
    static func noon(_ text: String) -> Date {
        let day = LocalDate(text)!
        return Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
    }

    struct Fixture {
        let database: AppDatabase
        let athlete: Athlete
        let jiuJitsu: Season
        let performance: Season
        /// Base volume 1, current.
        let current: Arc
    }

    /// Jiu-Jitsu (active) with Base volume 1 and 2, Performance with Adaptação; each arc has one template of
    /// Supino 3 × 8 (a goal of 1 a week) for 2 weeks.
    func setUp() async throws -> Fixture {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let seasons = SeasonService(database)
        let jiuJitsu = try await seasons.season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let performance = try await seasons.season(named: "Performance", athleteId: athlete.id)
        for (name, seasonId) in [
            ("Base volume 1", jiuJitsu.id), ("Base volume 2", jiuJitsu.id), ("Adaptação", performance.id),
        ] {
            let arc = try await ArcService(database).save(
                ArcDraft(
                    name: name, kanji: "試", weeks: 2, startDate: LocalDate("2026-11-02")!,
                    templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: seasonId)
            let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
            var draft = try #require(
                try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
            draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
            try await TemplateService(database).save(draft)
        }
        let current = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        return Fixture(
            database: database, athlete: athlete, jiuJitsu: jiuJitsu, performance: performance, current: current)
    }

    func pauses(_ f: Fixture) async throws -> [ArcPause] {
        try await f.database.writer.read { db in try ArcPause.order(Column("start_date")).fetchAll(db) }
    }

    func train(_ f: Fixture, on day: String) async throws {
        let plan = try #require(try await PlanRepository(f.database).plan(arcId: f.current.id))
        let sessions = SessionRepository(f.database)
        let session = try await sessions.start(plan.templates[0], now: Self.noon(day))
        _ = try await sessions.finish(sessionId: session.id, now: Self.noon(day).addingTimeInterval(3600))
    }

    @Test func pauseBlocksTrainingAndResumeOpensIt() async throws {
        let f = try await setUp()
        let service = ArcService(f.database)
        try await service.pause(arcId: f.current.id, now: Self.noon("2026-11-16"))
        #expect(try await service.isPaused(arcId: f.current.id))
        #expect(try await !service.canTrain(arcId: f.current.id))
        try await service.resume(arcId: f.current.id, now: Self.noon("2026-11-23"))
        #expect(try await !service.isPaused(arcId: f.current.id))
        #expect(try await service.canTrain(arcId: f.current.id))
        let stored = try await pauses(f)
        #expect(
            stored.map(\.interval) == [
                PauseInterval(startDate: LocalDate("2026-11-16")!, endDate: LocalDate("2026-11-23")!)
            ])
    }

    @Test func pauseRefusesAQueuedArcAndAPausedOne() async throws {
        let f = try await setUp()
        let service = ArcService(f.database)
        let queued = try #require(
            try await service.summaries(athleteId: f.athlete.id, seasonId: f.jiuJitsu.id).last?.arc)
        await #expect(throws: PersistenceError.cannotPause(queued.id)) {
            try await service.pause(arcId: queued.id)
        }
        try await service.pause(arcId: f.current.id)
        await #expect(throws: PersistenceError.cannotPause(f.current.id)) {
            try await service.pause(arcId: f.current.id)
        }
        #expect(try await pauses(f).count == 1)
    }

    @Test func pauseRefusesAFillerArc() async throws {
        let f = try await setUp()
        let filler = try await ArcService(f.database).save(
            ArcDraft(
                name: "Manutenção", kanji: "守", kind: .filler, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Patrulha")]),
            athleteId: f.athlete.id, seasonId: nil)
        await #expect(throws: PersistenceError.cannotPause(filler.id)) {
            try await ArcService(f.database).pause(arcId: filler.id)
        }
    }

    @Test func pauseRefusesWhileASessionIsInProgress() async throws {
        let f = try await setUp()
        let plan = try #require(try await PlanRepository(f.database).plan(arcId: f.current.id))
        _ = try await SessionRepository(f.database).start(plan.templates[0])
        await #expect(throws: PersistenceError.sessionInProgress(f.current.id)) {
            try await ArcService(f.database).pause(arcId: f.current.id)
        }
        #expect(try await pauses(f).isEmpty)
    }

    /// Two devices paused offline: resuming closes both.
    @Test func resumeClosesEveryOpenPause() async throws {
        let f = try await setUp()
        try await f.database.writer.write { [f] db in
            for day in ["2026-11-16", "2026-11-17"] {
                try ArcPause(
                    id: UUIDv7.make(), athleteId: f.athlete.id, arcId: f.current.id, startDate: LocalDate(day)!,
                    endDate: nil, createdAt: .now
                ).insert(db)
            }
        }
        try await ArcService(f.database).resume(arcId: f.current.id, now: Self.noon("2026-11-20"))
        #expect(try await pauses(f).map(\.endDate) == [LocalDate("2026-11-20"), LocalDate("2026-11-20")])
    }

    @Test func switchingSeasonClosesThePause() async throws {
        let f = try await setUp()
        try await ArcService(f.database).pause(arcId: f.current.id, now: Self.noon("2026-11-16"))
        try await SeasonService(f.database).activate(
            seasonId: f.performance.id, athleteId: f.athlete.id, now: Self.noon("2026-11-18"))
        #expect(try await pauses(f).map(\.endDate) == [LocalDate("2026-11-18")])
    }

    @Test func deactivatingClosesThePause() async throws {
        let f = try await setUp()
        try await ArcService(f.database).pause(arcId: f.current.id, now: Self.noon("2026-11-16"))
        try await SeasonService(f.database).deactivate(
            seasonId: f.jiuJitsu.id, athleteId: f.athlete.id, now: Self.noon("2026-11-19"))
        #expect(try await pauses(f).map(\.endDate) == [LocalDate("2026-11-19")])
    }

    /// The month turns in the monthly phase: the arc that leaves the current slot is resumed that day.
    @Test func monthTurnClosesThePause() async throws {
        let monthly = MonthlyArcServiceTests()
        let m = try await monthly.setUp()
        _ = try await monthly.finishOneSession(m, arc: "Adaptação", now: MonthlyArcServiceTests.day(11))
        let november = try #require(m.arcs["Novembro e Dezembro"])
        #expect(try await PlanRepository(m.database).currentArc(athleteId: m.athlete.id)?.id == november)
        try await ArcService(m.database).pause(arcId: november, now: Self.noon("2026-12-20"))
        try await SeasonService(m.database).alignMonthlyArc(athleteId: m.athlete.id, now: Self.noon("2027-01-01"))
        let stored = try await m.database.writer.read { db in try ArcPause.fetchAll(db) }
        #expect(stored.map(\.endDate) == [LocalDate("2027-01-01")])
    }

    /// Three weeks met, one paused, then the fifth: the workout summary shows Sequência Acesa.
    @Test func theWorkoutAfterAPauseUnlocksSequenciaAcesa() async throws {
        let f = try await setUp()
        for day in ["2026-11-02", "2026-11-09", "2026-11-16"] { try await train(f, on: day) }
        try await ArcService(f.database).pause(arcId: f.current.id, now: Self.noon("2026-11-23"))
        try await ArcService(f.database).resume(arcId: f.current.id, now: Self.noon("2026-11-30"))
        try await train(f, on: "2026-11-30")
        let last = try #require(try await SessionRepository(f.database).sessions(athleteId: f.athlete.id).first)
        let completion = try #require(try await ProgressService(f.database).completion(sessionId: last.id))
        #expect(completion.newTitles.contains(.streakLit))
    }

    /// An open pause left on an arc that is no longer current (or deleted) cannot be resumed: it must not protect
    /// every week from then on.
    @Test func anOpenPauseOnAnArcThatIsNotCurrentProtectsNothing() async throws {
        let f = try await setUp()
        try await train(f, on: "2026-11-03")
        let queued = try #require(
            try await ArcService(f.database).summaries(athleteId: f.athlete.id, seasonId: f.jiuJitsu.id).last?.arc)
        try await f.database.writer.write { [f] db in
            try ArcPause(
                id: UUIDv7.make(), athleteId: f.athlete.id, arcId: queued.id, startDate: LocalDate("2026-11-09")!,
                endDate: nil, createdAt: .now
            ).insert(db)
        }
        let streak = try await ProgressService(f.database).streak(
            athleteId: f.athlete.id, today: LocalDate("2026-11-24")!)
        #expect(streak.current == 0)
    }

    /// Two weeks met, the third paused without a workout: the streak stays at 2 in the fourth.
    @Test func pausedWeekKeepsTheStreak() async throws {
        let f = try await setUp()
        try await train(f, on: "2026-11-03")
        try await train(f, on: "2026-11-10")
        try await ArcService(f.database).pause(arcId: f.current.id, now: Self.noon("2026-11-16"))
        try await ArcService(f.database).resume(arcId: f.current.id, now: Self.noon("2026-11-23"))
        let streak = try await ProgressService(f.database).streak(
            athleteId: f.athlete.id, today: LocalDate("2026-11-24")!)
        #expect(streak.current == 2)
    }
}
