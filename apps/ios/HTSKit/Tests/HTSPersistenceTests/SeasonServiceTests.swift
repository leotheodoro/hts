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
}
