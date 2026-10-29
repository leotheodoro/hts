import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct ArcsModelTests {
    @Test func groupsArcsBySeasonAndKeepsFreeArcsApart() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let model = ArcsModel(database: database, athleteId: athlete.id)
        await model.load()
        #expect(model.seasons.isEmpty)
        #expect(model.freeArcs.isEmpty)

        let seasons = SeasonService(database)
        let jiuJitsu = try await seasons.season(named: "Jiu-Jitsu", athleteId: athlete.id)
        _ = try await seasons.season(named: "Performance", athleteId: athlete.id)
        await model.load()

        var draft = model.newDraft()
        draft.name = "Recrutamento"
        draft.kanji = "募"
        draft.weeks = 2
        draft.templates = ["Linha de Frente", "Trincheira"].map { .init(origin: .new, name: $0) }
        #expect(await model.save(draft))
        var filler = model.newDraft()
        filler.name = "Manutenção"
        filler.kanji = "守"
        filler.kind = .filler
        filler.templates = [.init(origin: .new, name: "PP")]
        #expect(await model.save(filler))

        #expect(model.seasons.map(\.season.name) == ["Jiu-Jitsu", "Performance"])
        #expect(model.activeSeason?.id == jiuJitsu.id)
        let arcs = model.seasons[0].summaries
        #expect(arcs.map(\.arc.name) == ["Recrutamento"])
        #expect(arcs.first?.arc.status == .current)
        #expect(arcs.first?.schedule.totalSessions == 4)
        #expect(model.freeArcs.map(\.arc.name) == ["Manutenção"])

        let editable = try #require(await model.draft(for: arcs[0].arc.id))
        #expect(editable.templates.map(\.name) == ["Linha de Frente", "Trincheira"])
    }

    @Test func activatingAnotherSeasonPausesTheCurrentArc() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let seasons = SeasonService(database)
        let jiuJitsu = try await seasons.season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let performance = try await seasons.season(named: "Performance", athleteId: athlete.id)
        let service = ArcService(database)
        for (name, season) in [("Base", jiuJitsu), ("Adaptação", performance)] {
            try await service.save(
                ArcDraft(
                    name: name, kanji: "試", weeks: 2, startDate: .today, templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: season.id)
        }
        let model = ArcsModel(database: database, athleteId: athlete.id)
        await model.load()
        await model.activate(performance)

        #expect(model.activeSeason?.id == performance.id)
        #expect(model.seasons.first?.season.name == "Performance")
        #expect(model.seasons.first?.summaries.first?.arc.status == .current)
        #expect(model.seasons.last?.summaries.first?.arc.status == .queued)
    }
}
