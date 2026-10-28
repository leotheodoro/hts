import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct TemplateServiceTests {
    /// An arc with one empty template A, as created by the arc form.
    func setUp() async throws -> (AppDatabase, Athlete, UUID) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", weeks: 2, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Linha de Frente")]),
            athleteId: athlete.id, sagaId: saga.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        return (database, athlete, plan.templates[0].template.id)
    }

    @Test func savesBlocksAndExercisesAndReadsThemBackAsTyped() async throws {
        let (database, _, templateId) = try await setUp()
        let service = TemplateService(database)
        var draft = try #require(try await service.draft(templateId: templateId))
        #expect(draft.blocks.isEmpty)
        draft.focus = "Força"
        draft.blocks = [
            .init(
                kind: .activation, attributes: [.mobility],
                exercises: [
                    .init(name: "Prancha", unit: .seconds, setsText: "3", targetText: "30-45 s")
                ]),
            .init(
                kind: .strength, attributes: [.strength],
                exercises: [
                    .init(name: "Zercher Squat", setsText: "4", targetText: "6-6-3-3", restSeconds: 150),
                    .init(name: "Afundo Búlgaro", setsText: "3 a 4", targetText: "10/10"),
                ]),
            .init(
                kind: .fightRound, attributes: [.conditioning, .power], durationMinutes: 8,
                exercises: [
                    .init(name: "Swing Russo", setsText: "1", targetText: "máx", restSeconds: 30)
                ]),
        ]
        #expect(draft.isValid)
        try await service.save(draft)

        let saved = try #require(try await service.draft(templateId: templateId))
        #expect(saved.focus == "Força")
        #expect(saved.blocks.map(\.kind) == [.activation, .strength, .fightRound])
        #expect(saved.blocks[2].durationMinutes == 8)
        #expect(saved.blocks[2].attributes == [.conditioning, .power])
        let typed = saved.blocks.flatMap(\.exercises).map { "\($0.name) \($0.setsText) × \($0.targetText)" }
        #expect(
            typed == [
                "Prancha 3 × 30-45 s", "Zercher Squat 4 × 6-6-3-3", "Afundo Búlgaro 3 a 4 × 10/10",
                "Swing Russo 1 × máx",
            ])
        #expect(saved.blocks[1].exercises[0].restSeconds == 150)
        #expect(saved.blocks[1].exercises[0].loadHint == .heavy)
    }

    @Test func editingKeepsIdsReordersAndSoftDeletes() async throws {
        let (database, athlete, templateId) = try await setUp()
        let service = TemplateService(database)
        var draft = try #require(try await service.draft(templateId: templateId))
        draft.blocks = [
            .init(exercises: [
                .init(name: "Supino", setsText: "3", targetText: "8"),
                .init(name: "Remada", setsText: "3", targetText: "8"),
            ])
        ]
        try await service.save(draft)
        var edit = try #require(try await service.draft(templateId: templateId))
        let supinoId = try #require(edit.blocks[0].exercises[0].existingId)
        edit.blocks[0].exercises.swapAt(0, 1)
        edit.blocks[0].exercises.removeLast()  // Supino
        edit.blocks[0].exercises.append(.init(name: "supino", setsText: "4", targetText: "5"))
        try await service.save(edit)

        let saved = try #require(try await service.draft(templateId: templateId))
        #expect(saved.blocks[0].exercises.map(\.name) == ["Remada", "Supino"])
        #expect(saved.blocks[0].exercises[1].existingId != supinoId)
        #expect(saved.blocks[0].exercises[1].targetText == "5")
        // "supino" reused the catalog exercise "Supino".
        let found = try await ExerciseCatalog(database).search("supino", athleteId: athlete.id)
        #expect(found.map(\.name) == ["Supino"])
    }

    @Test func invalidTargetsMakeTheDraftInvalid() {
        var exercise = TemplateDraft.ExerciseDraft(name: "Supino", setsText: "4", targetText: "6-6-3")
        #expect(!exercise.isValid)
        exercise.targetText = "6-6-3-3"
        #expect(exercise.isValid)
        exercise.setsText = "x"
        #expect(!exercise.isValid)
    }
}
