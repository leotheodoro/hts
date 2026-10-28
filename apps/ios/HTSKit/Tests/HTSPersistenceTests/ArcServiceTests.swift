import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct ArcServiceTests {
    let start = LocalDate("2026-11-02")!

    func setUp() async throws -> (AppDatabase, Athlete, Saga, ArcService) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        return (database, athlete, saga, service)
    }

    func draft(_ name: String, templates: [String] = ["Linha de Frente", "Trincheira", "Bombardeio"]) -> ArcDraft {
        ArcDraft(
            name: name, kanji: "募", weeks: 2, startDate: start,
            templates: templates.map { .init(origin: .new, name: $0) })
    }

    @Test func sagaIsCreatedOnceperYear() async throws {
        let (_, athlete, saga, service) = try await setUp()
        #expect(saga.name == "Saga 2026")
        #expect(try await service.saga(athleteId: athlete.id, year: 2026) == saga)
    }

    @Test func firstArcIsCurrentAndNextOnesQueue() async throws {
        let (_, athlete, saga, service) = try await setUp()
        let first = try await service.save(draft("Recrutamento"), athleteId: athlete.id, sagaId: saga.id)
        let second = try await service.save(draft("Forja"), athleteId: athlete.id, sagaId: saga.id)
        #expect(first.status == .current)
        #expect(second.status == .queued)
        let summaries = try await service.summaries(athleteId: athlete.id, sagaId: saga.id)
        #expect(summaries.map(\.arc.name) == ["Recrutamento", "Forja"])
        #expect(summaries[0].schedule.letters == ["A", "B", "C"])
        #expect(summaries[0].schedule.totalSessions == 6)
        #expect(summaries[0].schedule.endDate == LocalDate("2026-11-15"))
        #expect(summaries[0].completedSessions == 0)
    }

    @Test func editingReordersRenamesRemovesAndReuses() async throws {
        let (database, athlete, saga, service) = try await setUp()
        let first = try await service.save(draft("Recrutamento"), athleteId: athlete.id, sagaId: saga.id)
        let second = try await service.save(
            draft("Forja", templates: ["Blindado"]), athleteId: athlete.id, sagaId: saga.id)
        let firstPlan = try #require(try await PlanRepository(database).plan(arcId: first.id))

        var edit = ArcDraft(try #require(try await PlanRepository(database).plan(arcId: second.id)), today: start)
        edit.templates.insert(.init(origin: .reuse(firstPlan.templates[1].template.id), name: "Trincheira II"), at: 0)
        edit.weeks = 3
        try await service.save(edit, athleteId: athlete.id, sagaId: saga.id)

        let edited = try #require(try await PlanRepository(database).plan(arcId: second.id))
        #expect(edited.templates.map(\.template.letter) == ["A", "B"])
        #expect(edited.templates.map(\.template.name) == ["Trincheira II", "Blindado"])
        #expect(edited.templates[0].template.sourceTemplateId == firstPlan.templates[1].template.id)
        #expect(edited.arc.weeks == 3)

        // Removing a template soft-deletes it; the original arc keeps its own.
        edit = ArcDraft(edited, today: start)
        edit.templates.removeLast()
        try await service.save(edit, athleteId: athlete.id, sagaId: saga.id)
        #expect(try await PlanRepository(database).plan(arcId: second.id)?.templates.count == 1)
        #expect(try await PlanRepository(database).plan(arcId: first.id)?.templates.count == 3)
    }

    @Test func fillerArcHasNoDuration() async throws {
        let (_, athlete, saga, service) = try await setUp()
        var filler = draft("Manutenção", templates: ["Patrulha", "Sentinela"])
        filler.kind = .filler
        let arc = try await service.save(filler, athleteId: athlete.id, sagaId: saga.id)
        #expect(arc.weeks == nil)
        #expect(arc.startDate == nil)
    }

    @Test func progressCountsCompletedSessionsSinceTheLastReset() async throws {
        let (database, athlete, saga, service) = try await setUp()
        let arc = try await service.save(draft("Recrutamento"), athleteId: athlete.id, sagaId: saga.id)
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
        #expect(try await service.summaries(athleteId: athlete.id, sagaId: saga.id)[0].completedSessions == 2)

        try await service.restartCount(arcId: arc.id, now: t0.addingTimeInterval(2 * 86_400))
        #expect(try await service.summaries(athleteId: athlete.id, sagaId: saga.id)[0].completedSessions == 0)
        #expect(try await sessions.sessions(athleteId: athlete.id).count == 3)
    }
}
