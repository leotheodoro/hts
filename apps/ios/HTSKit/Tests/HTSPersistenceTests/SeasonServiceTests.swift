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
        #expect(
            try await ArcService(database).summaries(athleteId: athlete.id, seasonId: jiuJitsu.id).first?
                .completedSessions == 1)
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
