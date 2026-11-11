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

    /// Temporadas disponíveis (#204): an inactive season shows its first open arc as next; the confirmation names
    /// the arc whose count restarts.
    @Test func anInactiveSeasonShowsItsNextArcAndTheConfirmationNamesTheRestart() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let seasons = SeasonService(database)
        let jiuJitsu = try await seasons.season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let performance = try await seasons.season(named: "Performance", athleteId: athlete.id)
        let service = ArcService(database)
        for (name, season) in [("Força Máxima", jiuJitsu), ("Arranque", performance), ("Velocidade", performance)] {
            try await service.save(
                ArcDraft(
                    name: name, kanji: "試", weeks: 2, startDate: .today, templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: season.id)
        }
        let model = ArcsModel(database: database, athleteId: athlete.id)
        await model.load()
        #expect(
            model.activationNote(for: performance)
                == "A temporada Jiu-Jitsu fica inativa. XP, nível, treinos feitos e arcos já liberados continuam.")

        let current = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: current.id))
        let session = try await SessionRepository(database).start(plan.templates[0])
        _ = try await SessionRepository(database).finish(sessionId: session.id)
        await model.load()
        let other = try #require(model.seasons.first { $0.season.id == performance.id })
        #expect(model.upNextArcId(in: other) == other.summaries.first?.arc.id)
        let active = try #require(model.seasons.first { $0.season.id == jiuJitsu.id })
        #expect(model.upNextArcId(in: active) == nil)

        #expect(
            model.activationNote(for: performance)
                == "A temporada Jiu-Jitsu fica inativa e a contagem do arco Força Máxima (1 de 2) volta a zero. XP, nível, treinos feitos e arcos já liberados continuam."
        )
    }

    /// "Desativar temporada" (#214): the confirmation says what restarts; afterwards no season is active.
    @Test func deactivatingTheActiveSeason() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let season = try await SeasonService(database).season(named: "Power Building", athleteId: athlete.id)
        try await ArcService(database).save(
            ArcDraft(name: "Volume 1", kanji: "筋", startDate: .today, templates: [.init(origin: .new, name: "A")]),
            athleteId: athlete.id, seasonId: season.id)
        // Endless, as the seed imports it: no weeks.
        try await database.writer.write { db in
            try db.execute(sql: "UPDATE arc SET weeks = NULL, start_date = NULL WHERE name = 'Volume 1'")
        }
        let model = ArcsModel(database: database, athleteId: athlete.id)
        await model.load()
        #expect(
            model.deactivationNote()
                == "Nenhuma temporada fica ativa. XP, nível, treinos feitos e arcos já liberados continuam.")

        let current = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: current.id))
        let session = try await SessionRepository(database).start(plan.templates[0])
        _ = try await SessionRepository(database).finish(sessionId: session.id)
        await model.load()
        #expect(
            model.deactivationNote()
                == "Nenhuma temporada fica ativa e a contagem do arco Volume 1 (1) volta a zero. XP, nível, treinos feitos e arcos já liberados continuam."
        )

        await model.deactivate(season)
        #expect(model.activeSeason == nil)
        #expect(model.seasons.first?.summaries.first?.arc.status == .queued)
    }
}
