import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct ArcServiceTests {
    let start = LocalDate("2026-11-02")!

    func setUp() async throws -> (AppDatabase, Athlete, Season, ArcService) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        return (database, athlete, season, service)
    }

    func draft(_ name: String, templates: [String] = ["Linha de Frente", "Trincheira", "Bombardeio"]) -> ArcDraft {
        ArcDraft(
            name: name, kanji: "募", weeks: 2, startDate: start,
            templates: templates.map { .init(origin: .new, name: $0) })
    }

    @Test func seasonIsFoundByNameAndTheFirstOneIsActive() async throws {
        let (database, athlete, season, _) = try await setUp()
        #expect(season.name == "Jiu-Jitsu")
        #expect(season.active)
        #expect(try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id) == season)
        let other = try await SeasonService(database).season(named: "Performance", athleteId: athlete.id)
        #expect(!other.active)
        #expect(other.position == 1)
    }

    @Test func firstArcIsCurrentAndNextOnesQueue() async throws {
        let (_, athlete, season, service) = try await setUp()
        let first = try await service.save(draft("Recrutamento"), athleteId: athlete.id, seasonId: season.id)
        let second = try await service.save(draft("Forja"), athleteId: athlete.id, seasonId: season.id)
        #expect(first.status == .current)
        #expect(second.status == .queued)
        let summaries = try await service.summaries(athleteId: athlete.id, seasonId: season.id)
        #expect(summaries.map(\.arc.name) == ["Recrutamento", "Forja"])
        #expect(summaries[0].schedule.letters == ["A", "B", "C"])
        #expect(summaries[0].schedule.totalSessions == 6)
        #expect(summaries[0].schedule.endDate == LocalDate("2026-11-15"))
        #expect(summaries[0].completedSessions == 0)
    }

    @Test func editingReordersRenamesRemovesAndReuses() async throws {
        let (database, athlete, season, service) = try await setUp()
        let first = try await service.save(draft("Recrutamento"), athleteId: athlete.id, seasonId: season.id)
        let second = try await service.save(
            draft("Forja", templates: ["Blindado"]), athleteId: athlete.id, seasonId: season.id)
        let firstPlan = try #require(try await PlanRepository(database).plan(arcId: first.id))

        var edit = ArcDraft(try #require(try await PlanRepository(database).plan(arcId: second.id)), today: start)
        edit.templates.insert(.init(origin: .reuse(firstPlan.templates[1].template.id), name: "Trincheira II"), at: 0)
        edit.weeks = 3
        try await service.save(edit, athleteId: athlete.id, seasonId: season.id)

        let edited = try #require(try await PlanRepository(database).plan(arcId: second.id))
        #expect(edited.templates.map(\.template.letter) == ["A", "B"])
        #expect(edited.templates.map(\.template.name) == ["Trincheira II", "Blindado"])
        #expect(edited.templates[0].template.sourceTemplateId == firstPlan.templates[1].template.id)
        #expect(edited.arc.weeks == 3)

        // Removing a template soft-deletes it; the original arc keeps its own.
        edit = ArcDraft(edited, today: start)
        edit.templates.removeLast()
        try await service.save(edit, athleteId: athlete.id, seasonId: season.id)
        #expect(try await PlanRepository(database).plan(arcId: second.id)?.templates.count == 1)
        #expect(try await PlanRepository(database).plan(arcId: first.id)?.templates.count == 3)
    }

    @Test func fillerArcHasNoDuration() async throws {
        let (_, athlete, season, service) = try await setUp()
        var filler = draft("Manutenção", templates: ["Patrulha", "Sentinela"])
        filler.kind = .filler
        let arc = try await service.save(filler, athleteId: athlete.id, seasonId: season.id)
        #expect(arc.weeks == nil)
        #expect(arc.startDate == nil)
    }

    @Test func progressCountsCompletedSessionsSinceTheLastReset() async throws {
        let (database, athlete, season, service) = try await setUp()
        let arc = try await service.save(draft("Recrutamento"), athleteId: athlete.id, seasonId: season.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        let sessions = SessionRepository(database)
        let utc = TimeZone(identifier: "UTC")!
        let t0 = Date(timeIntervalSince1970: 1_793_000_000)
        for i in 0..<2 {
            let s = try await sessions.start(
                plan.templates[i], now: t0.addingTimeInterval(Double(i) * 86_400), timeZone: utc)
            _ = try await sessions.finish(sessionId: s.id, now: t0.addingTimeInterval(Double(i) * 86_400 + 3600))
        }
        _ = try await sessions.start(plan.templates[2], now: t0.addingTimeInterval(3 * 86_400), timeZone: utc)
        #expect(try await service.summaries(athleteId: athlete.id, seasonId: season.id)[0].completedSessions == 2)

        try await service.restartCount(arcId: arc.id, now: t0.addingTimeInterval(2 * 86_400))
        #expect(try await service.summaries(athleteId: athlete.id, seasonId: season.id)[0].completedSessions == 0)
        #expect(try await sessions.sessions(athleteId: athlete.id).count == 3)
    }
}

@Suite struct FillerArcTests {
    let start = LocalDate("2026-11-02")!

    @Test func fillerNeverTakesTheCurrentSlotAndIsNeverPromoted() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let filler = try await service.save(
            ArcDraft(
                name: "Manutenção", kanji: "守", kind: .filler, startDate: start,
                templates: [.init(origin: .new, name: "PP"), .init(origin: .new, name: "FB")]),
            athleteId: athlete.id, seasonId: season.id)
        #expect(filler.status == .queued)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id) == nil)

        let normal = try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "試", weeks: 1, startDate: start,
                templates: [.init(origin: .new, name: "A")]),
            athleteId: athlete.id, seasonId: season.id)
        #expect(normal.status == .current)

        // Closing the normal arc does not promote the filler.
        let plan = try #require(try await PlanRepository(database).plan(arcId: normal.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "1", targetText: "8")])]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: normal.id)?.templates.first)
        let sessions = SessionRepository(database)
        let session = try await sessions.start(filled)
        _ = try await sessions.finish(sessionId: session.id)
        #expect(try await service.completeIfDone(arcId: normal.id) == nil)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id) == nil)

        let fillers = try await service.fillerPlans(athleteId: athlete.id)
        #expect(fillers.map(\.arc.name) == ["Manutenção"])
        #expect(fillers[0].templates.map(\.template.name) == ["PP", "FB"])
    }

    @Test func migrationMovesAnOldCurrentFillerToTheQueue() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let old = Arc(
            id: UUIDv7.make(), athleteId: athlete.id, seasonId: season.id, name: "Manutenção", kind: .filler,
            weeks: nil, startDate: nil, status: .current, position: 0, createdAt: .now.addingTimeInterval(-60))
        try await database.writer.write { db in try old.insert(db) }
        // Re-run the data fix the way the migrator does on an existing install.
        try await database.writer.write { db in
            try db.execute(
                sql:
                    "UPDATE arc SET status = 'queued', updated_at = ? WHERE kind = 'filler' AND status = 'current' AND deleted_at IS NULL",
                arguments: [ISO8601Millis.format(.now)])
        }
        let stored = try #require(
            try await PlanRepository(database).arcs(athleteId: athlete.id, seasonId: season.id).first)
        #expect(stored.status == .queued)
        #expect(stored.updatedAt > old.updatedAt)
    }
}
