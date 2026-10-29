import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct StarterPlanTests {
    static func plan(_ jiuJitsuArcs: [String]) -> String {
        let arcs = jiuJitsuArcs.map { name in
            """
            { "name": "\(name)", "kanji": "試", "weeks": 2, "templates": [
              { "name": "A", "blocks": [{ "kind": "strength", "attributes": ["strength"], "exercises": [
                { "name": "Supino máquina", "sets": "3", "target": "8" } ] }] } ] }
            """
        }.joined(separator: ",")
        return """
            {
              "seasons": [
                { "name": "Jiu-Jitsu", "arcs": [\(arcs)] },
                { "name": "Performance", "arcs": [
                  { "name": "Adaptação", "kanji": "適", "weeks": 2, "templates": [
                    { "name": "A", "blocks": [{ "kind": "strength", "attributes": ["strength"], "exercises": [
                      { "name": "Leg press", "sets": "2", "target": "20" } ] }] } ] } ] }
              ],
              "arcs": [
                { "name": "Manutenção", "kanji": "守", "templates": [
                  { "name": "PP", "focus": "Carga moderada a leve", "blocks": [
                    { "kind": "activation", "attributes": ["mobility"], "exercises": [
                      { "name": "Rotação externa de ombros", "sets": "2", "target": "15/15" } ] },
                    { "kind": "core", "attributes": ["core"], "exercises": [
                      { "name": "Prancha frontal", "unit": "seconds", "sets": "2", "target": "45 s" } ] } ] } ] }
              ]
            }
            """
    }

    func setUp() async throws -> (AppDatabase, Athlete) {
        let database = try AppDatabase.inMemory()
        return (database, try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo"))
    }

    func decode(_ json: String) throws -> StarterPlan {
        try JSONDecoder().decode(StarterPlan.self, from: Data(json.utf8))
    }

    @Test func importsSeasonsInOrderAndFreeArcs() async throws {
        let (database, athlete) = try await setUp()
        let today = LocalDate("2026-10-29")!
        let added = try await decode(Self.plan(["Base volume 1", "Base volume 2"]))
            .importMissing(into: database, athleteId: athlete.id, today: today)
        #expect(added == 4)

        let seasons = try await SeasonService(database).seasons(athleteId: athlete.id)
        #expect(seasons.map(\.name) == ["Jiu-Jitsu", "Performance"])
        #expect(seasons.map(\.active) == [true, false])

        let jiuJitsu = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: seasons[0].id)
        #expect(jiuJitsu.map(\.arc.name) == ["Base volume 1", "Base volume 2"])
        #expect(jiuJitsu.map(\.arc.status) == [.current, .queued])
        let performance = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: seasons[1].id)
        #expect(performance.map(\.arc.status) == [.queued])

        let free = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: nil)
        #expect(free.map(\.arc.name) == ["Manutenção"])
        #expect(free[0].arc.kind == .filler)
        #expect(free[0].arc.kanji == "守")
        let manutencao = try #require(try await PlanRepository(database).plan(arcId: free[0].arc.id))
        #expect(manutencao.templates[0].blocks.map(\.block.kind) == [.activation, .core])
        #expect(manutencao.templates[0].blocks[0].exercises[0].exercise.perSide)
    }

    @Test func importIsAdditiveByName() async throws {
        let (database, athlete) = try await setUp()
        let today = LocalDate("2026-10-29")!
        try await decode(Self.plan(["Base volume 1"])).importMissing(
            into: database, athleteId: athlete.id, today: today)
        #expect(
            try await decode(Self.plan(["Base volume 1"])).importMissing(
                into: database, athleteId: athlete.id, today: today) == 0)

        // Two months later: one more arc appended to the season.
        let added = try await decode(Self.plan(["Base volume 1", "Atual"]))
            .importMissing(into: database, athleteId: athlete.id, today: today)
        #expect(added == 1)
        let season = try #require(try await SeasonService(database).activeSeason(athleteId: athlete.id))
        let arcs = try await ArcService(database).summaries(athleteId: athlete.id, seasonId: season.id)
        #expect(arcs.map(\.arc.name) == ["Base volume 1", "Atual"])
        #expect(arcs.map(\.arc.status) == [.current, .queued])
    }

    @Test func everyArcNeedsAKanji() {
        #expect(throws: DecodingError.self) {
            try decode(#"{ "arcs": [{ "name": "Mobilidade", "templates": [] }] }"#)
        }
        var draft = ArcDraft(
            name: "Base", kanji: " ", weeks: 2, startDate: LocalDate("2026-11-02")!,
            templates: [.init(origin: .new, name: "A")])
        #expect(!draft.isValid)
        draft.kanji = "基"
        #expect(draft.isValid)
    }
}

@Suite struct SeasonServiceTests {
    @Test func arcsUnlockInOrderAndSeasonsPauseWhereTheyStopped() async throws {
        let (database, athlete) = try await StarterPlanTests().setUp()
        let today = LocalDate("2026-10-29")!
        try await StarterPlanTests().decode(StarterPlanTests.plan(["Base volume 1", "Base volume 2"]))
            .importMissing(into: database, athleteId: athlete.id, today: today)
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
