import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct ActiveSessionModelTests {
    func setUp() async throws -> (AppDatabase, AppModel) {
        let database = try AppDatabase.inMemory()
        let app = AppModel(database: database, apiConfiguration: nil, requestNotifications: {})
        await app.loadLocalAthlete()
        let athlete = try #require(app.athlete)
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "試", weeks: 2, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Linha de Frente")]),
            athleteId: athlete.id, seasonId: season.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var template = try #require(
            try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        template.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
        try await TemplateService(database).save(template)
        return (database, app)
    }

    @Test func startCheckAndFinishSurviveAReload() async throws {
        let (database, app) = try await setUp()
        let athlete = try #require(app.athlete)
        let arc = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
        await app.startWorkout(plan)
        let session = try #require(app.activeSession)
        #expect(app.showsActiveSession)

        let model = ActiveSessionModel(database: database, session: session, alerts: FakeRestAlerts())
        await model.load()
        let exercise = session.planSnapshot.blocks[0].exercises[0]
        #expect(model.rows(for: exercise).count == 3)
        #expect(model.uncheckedCount == 3)

        var first = model.rows(for: exercise)[0]
        first.weightKg = Decimal(string: "62.5")
        model.update(first)
        model.toggle(model.rows(for: exercise)[0], exercise: exercise)
        try await Task.sleep(for: .milliseconds(100))

        // A fresh model (as after killing the app) reads the same state from SQLite.
        let reloaded = ActiveSessionModel(database: database, session: session, alerts: FakeRestAlerts())
        await reloaded.load()
        let saved = reloaded.rows(for: exercise)[0]
        #expect(saved.completed)
        #expect(saved.weightKg == Decimal(string: "62.5"))
        #expect(saved.reps == 8)
        #expect(reloaded.uncheckedCount == 2)

        #expect(await reloaded.finish()?.status == .completed)
        app.endWorkout()
        #expect(try await SessionRepository(database).inProgress(athleteId: athlete.id) == nil)
    }

    @Test func aBlockIsDoneWhenEverySetIsCheckedAndThePagerOpensOnTheFirstPending() async throws {
        let (database, app) = try await setUp()
        let athlete = try #require(app.athlete)
        let arc = try #require(try await PlanRepository(database).currentArc(athleteId: athlete.id))
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
        await app.startWorkout(plan)
        let model = ActiveSessionModel(
            database: database, session: try #require(app.activeSession), alerts: FakeRestAlerts())
        await model.load()
        let block = model.snapshot.blocks[0]
        #expect(!model.isDone(block))
        #expect(model.firstPendingPage == 0)

        for set in model.rows(for: block.exercises[0]) { model.toggle(set, exercise: block.exercises[0]) }
        #expect(model.isDone(block))
        // Every block done: the workout opens on the finish page.
        #expect(model.firstPendingPage == 1)
    }
}

@Suite struct NumberFieldTests {
    @Test func parsesCommaAndDotDecimals() {
        #expect(NumberField.parse("62,5") == Decimal(string: "62.5"))
        #expect(NumberField.parse("12") == 12)
        #expect(NumberField.parse("") == nil)
        #expect(NumberField.parse("abc") == nil)
    }
}
