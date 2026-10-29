import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct StatusModelTests {
    @Test func showsLevelNextWorkoutAndWeek() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "試", weeks: 2, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Linha de Frente"), .init(origin: .new, name: "Trincheira")]),
            athleteId: athlete.id, seasonId: season.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "1", targetText: "8")])]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)

        let model = StatusModel(database: database, athleteId: athlete.id)
        await model.load(today: LocalDate("2026-11-04")!)
        #expect(model.history?.totalXp == 0)
        #expect(model.next?.plan.template.letter == "A")
        #expect(model.weekGoal == 2)

        let sessions = SessionRepository(database)
        let monday = Date(timeIntervalSince1970: 1_794_142_800)  // 2026-11-03T12:00Z
        let session = try await sessions.start(filled, now: monday, timeZone: TimeZone(identifier: "UTC")!)
        for var set in try await sessions.sets(sessionId: session.id) {
            set.completed = true
            try await sessions.save(set)
        }
        _ = try await sessions.finish(sessionId: session.id, now: monday.addingTimeInterval(3600))

        await model.load(today: LocalDate("2026-11-04")!)
        #expect(model.history?.totalXp == 50)
        #expect(model.next?.plan.template.letter == "B")
        #expect(model.next?.completed == 1)
        #expect(model.weekDone == 1)
    }

    @Test func fillerArcsAreAlwaysAvailableOutsideTheCurrentArc() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        try await service.save(
            ArcDraft(
                name: "Manutenção", kanji: "守", kind: .filler, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "PP"), .init(origin: .new, name: "FB")]),
            athleteId: athlete.id, seasonId: season.id)
        let model = StatusModel(database: database, athleteId: athlete.id)
        await model.load(today: LocalDate("2026-11-04")!)
        #expect(model.next == nil)
        #expect(model.fillers.flatMap(\.templates).map(\.template.name) == ["PP", "FB"])

        try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "試", weeks: 2, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Linha de Frente")]),
            athleteId: athlete.id, seasonId: season.id)
        await model.load(today: LocalDate("2026-11-04")!)
        #expect(model.next?.arc.name == "Recrutamento")
        #expect(model.fillers.count == 1)
    }
}
