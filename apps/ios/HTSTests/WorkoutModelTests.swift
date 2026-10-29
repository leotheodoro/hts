import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct WorkoutModelTests {
    @Test func onlyTheCurrentArcAndFreeArcsCanStart() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let service = ArcService(database)
        func arc(_ name: String, kind: ArcKind = .normal, seasonId: UUID?) async throws -> TemplatePlan {
            let arc = try await service.save(
                ArcDraft(
                    name: name, kanji: "試", kind: kind, weeks: 2, startDate: .today,
                    templates: [.init(origin: .new, name: "A")]),
                athleteId: athlete.id, seasonId: seasonId)
            let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
            var draft = try #require(try await TemplateService(database).draft(templateId: plan.template.id))
            draft.blocks = [
                TemplateDraft.BlockDraft(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])
            ]
            try await TemplateService(database).save(draft)
            return plan
        }
        let current = try await arc("Base 1", seasonId: season.id)
        let locked = try await arc("Base 2", seasonId: season.id)
        let free = try await arc("Mobilidade", kind: .filler, seasonId: nil)

        for (plan, expected) in [(current, WorkoutModel.Start.available), (locked, .locked), (free, .available)] {
            let model = WorkoutModel(database: database, templateId: plan.template.id)
            await model.load()
            #expect(model.plan?.blocks.count == 1)
            #expect(model.start(hasActiveSession: false) == expected)
        }
        let model = WorkoutModel(database: database, templateId: current.template.id)
        await model.load()
        #expect(model.start(hasActiveSession: true) == .busy)
    }
}
