import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct SeasonServiceTests {
    /// Jiu-Jitsu (active) with Base volume 1 and 2, Performance with Adaptação; each arc has one template of
    /// Supino 3 × 8 for 2 weeks.
    func setUp() async throws -> (AppDatabase, Athlete) {
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
                    name: name, kanji: "試", weeks: 2, startDate: LocalDate("2026-10-29")!,
                    templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: seasonId)
            let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
            var draft = try #require(
                try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
            draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
            try await TemplateService(database).save(draft)
        }
        return (database, athlete)
    }

    @Test func arcsUnlockInOrderAndSeasonsPauseWhereTheyStopped() async throws {
        let (database, athlete) = try await setUp()
        let seasons = SeasonService(database)
        let all = try await seasons.seasons(athleteId: athlete.id)
        let (jiuJitsu, performance) = (all[0], all[1])
        let arcs = ArcService(database)

        // Finish Base volume 1: Base volume 2 unlocks.
        let first = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        var plan = try #require(try await PlanRepository(database).plan(arcId: first.id))
        let sessions = SessionRepository(database)
        for _ in 0..<2 {
            let session = try await sessions.start(plan.templates[0])
            _ = try await sessions.finish(sessionId: session.id)
        }
        let next = try await arcs.completeIfDone(arcId: first.id)
        #expect(next?.name == "Base volume 2")

        // Switch to Performance: Jiu-Jitsu pauses on Base volume 2.
        try await seasons.activate(seasonId: performance.id, athleteId: athlete.id)
        #expect(try await seasons.activeSeason(athleteId: athlete.id)?.id == performance.id)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id)?.name == "Adaptação")

        // Back to Jiu-Jitsu: it continues from Base volume 2.
        try await seasons.activate(seasonId: jiuJitsu.id, athleteId: athlete.id)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id)?.name == "Base volume 2")
        let jiu = try await arcs.summaries(athleteId: athlete.id, seasonId: jiuJitsu.id)
        #expect(jiu.map(\.arc.status) == [.completed, .current])
        plan = try #require(try await PlanRepository(database).plan(arcId: jiu[1].arc.id))
        #expect(plan.templates.count == 1)
    }

    /// Noon of a calendar day in the device time zone, where the app reads the dates of an arc.
    static func noon(_ text: String) -> Date {
        let day = LocalDate(text)!
        return Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
    }

    /// Finishes the two workouts of Base volume 1 on Thursday and Friday 12-13/11.
    func finishFirstArc(_ database: AppDatabase, _ athlete: Athlete) async throws -> Arc? {
        let first = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: first.id))
        let sessions = SessionRepository(database)
        for day in ["2026-11-12", "2026-11-13"] {
            let session = try await sessions.start(plan.templates[0], now: Self.noon(day))
            _ = try await sessions.finish(sessionId: session.id, now: Self.noon(day).addingTimeInterval(3600))
        }
        return try await ArcService(database).completeIfDone(
            arcId: first.id, now: Self.noon("2026-11-13").addingTimeInterval(3600))
    }

    /// The next arc starts on the Monday after the previous one ends, so it is not ATRASADO (#220).
    @Test func nextArcStartsOnTheFollowingMonday() async throws {
        let (database, athlete) = try await setUp()
        let next = try #require(try await finishFirstArc(database, athlete))
        #expect(next.name == "Base volume 2")
        #expect(next.startDate == LocalDate("2026-11-16"))
        let summary = try #require(
            try await ArcService(database).summaries(athleteId: athlete.id, seasonId: next.seasonId!)
                .first { $0.arc.id == next.id })
        #expect(!summary.schedule.isOverdue(today: LocalDate("2026-11-13")!, completedSessions: 0))
        #expect(summary.schedule.endDate == LocalDate("2026-11-29"))
    }

    /// An arc made current before #220 kept the import date: the app moves it to the Monday after the last workout
    /// of the completed arcs, once.
    @Test func alignStartDateRepairsAnArcThatStartedAtImport() async throws {
        let (database, athlete) = try await setUp()
        var next = try #require(try await finishFirstArc(database, athlete))
        next.startDate = LocalDate("2026-10-29")
        try await database.writer.write { [next] db in try next.update(db) }

        let seasons = SeasonService(database)
        let now = Self.noon("2026-11-13").addingTimeInterval(7200)
        try await seasons.alignStartDate(athleteId: athlete.id, now: now)
        let repaired = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        #expect(repaired.startDate == LocalDate("2026-11-16"))
        #expect(repaired.updatedAt == now.roundedToMilliseconds)

        try await seasons.alignStartDate(athleteId: athlete.id, now: now.addingTimeInterval(86_400))
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id)?.updatedAt == repaired.updatedAt)
    }

    /// The first arc of a season has no completed arc before it: its start date stays.
    @Test func alignStartDateKeepsTheFirstArc() async throws {
        let (database, athlete) = try await setUp()
        try await SeasonService(database).alignStartDate(athleteId: athlete.id)
        #expect(
            try await PlanRepository(database).currentArc(athleteId: athlete.id)?.startDate == LocalDate("2026-10-29"))
    }

    /// Activating another season restarts the paused arc (#204): its count goes back to zero, while the workouts,
    /// the completed arcs and the order stay.
    @Test func activatingAnotherSeasonRestartsThePausedArc() async throws {
        let (database, athlete) = try await setUp()
        let seasons = SeasonService(database)
        let all = try await seasons.seasons(athleteId: athlete.id)
        let (jiuJitsu, performance) = (all[0], all[1])
        let arcs = ArcService(database)
        let sessions = SessionRepository(database)
        let t0 = Date(timeIntervalSince1970: 1_794_142_800)

        // Base volume 1 done, then one workout of Base volume 2.
        let first = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let firstPlan = try #require(try await PlanRepository(database).plan(arcId: first.id))
        for day in 0..<2 {
            let session = try await sessions.start(
                firstPlan.templates[0], now: t0.addingTimeInterval(Double(day) * 86_400))
            _ = try await sessions.finish(
                sessionId: session.id, now: t0.addingTimeInterval(Double(day) * 86_400 + 3600))
        }
        _ = try await arcs.completeIfDone(arcId: first.id)
        let second = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let secondPlan = try #require(try await PlanRepository(database).plan(arcId: second.id))
        let session = try await sessions.start(secondPlan.templates[0], now: t0.addingTimeInterval(3 * 86_400))
        _ = try await sessions.finish(sessionId: session.id, now: t0.addingTimeInterval(3 * 86_400 + 3600))
        #expect(
            try await arcs.summaries(athleteId: athlete.id, seasonId: jiuJitsu.id).map(\.completedSessions) == [2, 1])

        try await seasons.activate(
            seasonId: performance.id, athleteId: athlete.id, now: t0.addingTimeInterval(4 * 86_400))
        try await seasons.activate(seasonId: jiuJitsu.id, athleteId: athlete.id, now: t0.addingTimeInterval(5 * 86_400))

        let jiu = try await arcs.summaries(athleteId: athlete.id, seasonId: jiuJitsu.id)
        #expect(jiu.map(\.arc.status) == [.completed, .current])
        #expect(jiu.map(\.completedSessions) == [2, 0])
        #expect(try await sessions.sessions(athleteId: athlete.id).count == 3)
    }

    /// Activating the season that is already active changes nothing.
    @Test func activatingTheActiveSeasonKeepsTheCount() async throws {
        let (database, athlete) = try await setUp()
        let seasons = SeasonService(database)
        let jiuJitsu = try #require(try await seasons.activeSeason(athleteId: athlete.id))
        let current = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: current.id))
        let sessions = SessionRepository(database)
        let session = try await sessions.start(plan.templates[0])
        _ = try await sessions.finish(sessionId: session.id)
        try await seasons.activate(seasonId: jiuJitsu.id, athleteId: athlete.id)
        let summary = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: jiuJitsu.id).first
        #expect(summary?.completedSessions == 1)
        #expect(summary?.arc.startDate == current.startDate)
    }

    /// "Desativar temporada" (#214): no season stays active; the current arc goes back to the queue with its count
    /// restarted, and comes back as current when the season is activated again.
    @Test func deactivatingLeavesNoSeasonActive() async throws {
        let (database, athlete) = try await setUp()
        let seasons = SeasonService(database)
        let jiuJitsu = try #require(try await seasons.activeSeason(athleteId: athlete.id))
        let now = Date(timeIntervalSince1970: 1_794_400_000)
        try await seasons.deactivate(seasonId: jiuJitsu.id, athleteId: athlete.id, now: now)
        #expect(try await seasons.activeSeason(athleteId: athlete.id) == nil)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id) == nil)
        let arcs = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: jiuJitsu.id)
        #expect(arcs[0].arc.status == .queued)
        #expect(arcs[0].arc.countResetAt == now)

        try await seasons.activate(seasonId: jiuJitsu.id, athleteId: athlete.id, now: now)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id)?.name == "Base volume 1")
    }
}
