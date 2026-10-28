import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct ArcsModelTests {
    @Test func createsTheSagaAndSavesArcs() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let model = ArcsModel(database: database, athleteId: athlete.id)
        await model.load()
        #expect(model.saga?.year == LocalDate.today.year)
        #expect(model.summaries.isEmpty)

        var draft = model.newDraft()
        draft.name = "Recrutamento"
        draft.weeks = 2
        draft.templates = ["Linha de Frente", "Trincheira"].map { .init(origin: .new, name: $0) }
        #expect(await model.save(draft))
        #expect(model.summaries.map(\.arc.name) == ["Recrutamento"])
        #expect(model.summaries.first?.schedule.totalSessions == 4)

        let editable = try #require(await model.draft(for: model.summaries[0].arc.id))
        #expect(editable.templates.map(\.name) == ["Linha de Frente", "Trincheira"])
    }
}
