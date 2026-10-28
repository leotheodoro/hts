import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct StarterPlanTests {
    let json = """
        {
          "arcs": [{
            "name": "Manutenção", "weeks": 1,
            "templates": [
              { "name": "PP", "focus": "Carga moderada a leve", "blocks": [
                { "kind": "activation", "attributes": ["mobility"], "exercises": [
                  { "name": "Rotação externa de ombros", "sets": "2", "target": "15/15" } ] },
                { "kind": "strength", "attributes": ["strength"], "exercises": [
                  { "name": "Supino máquina", "sets": "3", "target": "8" } ] } ] },
              { "name": "FB", "blocks": [
                { "kind": "activation", "attributes": ["core"], "exercises": [
                  { "name": "Prancha frontal", "unit": "seconds", "sets": "2", "target": "45 s" } ] } ] }
            ]
          }]
        }
        """

    @Test func importsOnceIntoAnEmptyAthlete() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let plan = try JSONDecoder().decode(StarterPlan.self, from: Data(json.utf8))
        let today = LocalDate("2026-10-28")!

        #expect(try await plan.importIfNeeded(into: database, athleteId: athlete.id, today: today))
        #expect(try await !plan.importIfNeeded(into: database, athleteId: athlete.id, today: today))

        let arc = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        #expect(arc.name == "Manutenção")
        #expect(arc.weeks == 1)
        let arcPlan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        #expect(arcPlan.templates.map(\.template.letter) == ["A", "B"])
        #expect(arcPlan.templates[0].template.focus == "Carga moderada a leve")
        let rotation = arcPlan.templates[0].blocks[0].exercises[0]
        #expect(rotation.exercise.perSide)
        #expect(rotation.prescription.targets == [.fixed(15)])
        let plank = arcPlan.templates[1].blocks[0].exercises[0]
        #expect(plank.exercise.unit == .seconds)
        #expect(plank.prescription.targets == [.fixed(45)])
    }

    @Test func skipsWhenTheAthleteAlreadyHasArcs() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        try await service.save(
            ArcDraft(
                name: "Do servidor", weeks: 1, startDate: LocalDate("2026-10-28")!,
                templates: [.init(origin: .new, name: "X")]),
            athleteId: athlete.id, sagaId: saga.id)
        let plan = try JSONDecoder().decode(StarterPlan.self, from: Data(json.utf8))
        #expect(try await !plan.importIfNeeded(into: database, athleteId: athlete.id, today: LocalDate("2026-10-28")!))
    }
}
