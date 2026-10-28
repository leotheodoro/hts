import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct JournalModelTests {
    @Test func listsNewestFirstAndRecomputesAfterDelete() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        let arc = try await service.save(
            ArcDraft(
                name: "Arco", weeks: 4, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Treino")]),
            athleteId: athlete.id, sagaId: saga.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "1", targetText: "8")])]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)

        let sessions = SessionRepository(database)
        let t0 = Date(timeIntervalSince1970: 1_794_142_800)
        var ids: [UUID] = []
        for (day, kg) in [(0, 60), (1, 70)] {
            let start = t0.addingTimeInterval(Double(day) * 86_400)
            let session = try await sessions.start(filled, now: start, timeZone: TimeZone(identifier: "UTC")!)
            for var set in try await sessions.sets(sessionId: session.id) {
                set.weightKg = Decimal(kg)
                set.reps = 8
                set.completed = true
                try await sessions.save(set)
            }
            ids.append(try await sessions.finish(sessionId: session.id, now: start.addingTimeInterval(3600)).id)
        }

        let model = JournalModel(database: database, athleteId: athlete.id)
        await model.load()
        #expect(model.entries.map(\.session.id) == ids.reversed())
        #expect(model.entries.map(\.number) == [2, 1])
        #expect(model.totalSets == 2)
        #expect(model.totalVolume == 1040)
        #expect(model.records.first?.weightKg == 70)

        await model.delete(model.entries[0].session)
        #expect(model.entries.count == 1)
        #expect(model.records.first?.weightKg == 60)
        #expect(LoggedSet.plate(kg: Decimal(string: "62.5")!, reps: 6) == "062.5 KG × 06")
    }
}
