import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

actor FakeRestAlerts: RestAlerts {
    private(set) var scheduled: [Date] = []
    private(set) var cancelled = 0

    func schedule(at date: Date, exerciseName: String) async { scheduled.append(date) }
    func cancel() async { cancelled += 1 }
}

@MainActor
@Suite struct RestTimerModelTests {
    func makeModel(
        restSeconds: Int?, blocks: [TemplateDraft.BlockDraft]? = nil
    ) async throws -> (ActiveSessionModel, FakeRestAlerts, PlanSnapshot.Exercise) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        let arc = try await service.save(
            ArcDraft(
                name: "Arco", weeks: 1, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Treino")]),
            athleteId: athlete.id, sagaId: saga.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks =
            blocks ?? [
                .init(exercises: [.init(name: "Swing", setsText: "2", targetText: "10", restSeconds: restSeconds)])
            ]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
        let session = try await SessionRepository(database).start(filled)
        let alerts = FakeRestAlerts()
        let model = ActiveSessionModel(database: database, session: session, defaultRestSeconds: 90, alerts: alerts)
        await model.load()
        return (model, alerts, session.planSnapshot.blocks[0].exercises[0])
    }

    @Test func checkingASetStartsTheExerciseRest() async throws {
        let (model, alerts, exercise) = try await makeModel(restSeconds: 30)
        model.toggle(model.rows(for: exercise)[0], exercise: exercise)
        let rest = try #require(model.rest)
        #expect(rest.duration == 30)
        #expect(model.restExerciseName == "Swing")
        try await Task.sleep(for: .milliseconds(50))
        #expect(await alerts.scheduled.count == 1)
        model.skipRest()
    }

    @Test func defaultRestAppliesWithoutOwnRestAndAdjustsReschedule() async throws {
        let (model, alerts, exercise) = try await makeModel(restSeconds: nil)
        model.toggle(model.rows(for: exercise)[0], exercise: exercise)
        #expect(model.rest?.duration == 90)
        model.adjustRest(by: 15)
        #expect((model.rest?.remaining(at: .now) ?? 0) > 100)
        model.skipRest()
        #expect(model.rest == nil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await alerts.scheduled.count == 2)
        #expect(await alerts.cancelled == 1)
    }

    @Test func uncheckingDoesNotStartARest() async throws {
        let (model, _, exercise) = try await makeModel(restSeconds: 30)
        model.toggle(model.rows(for: exercise)[0], exercise: exercise)
        model.skipRest()
        model.toggle(model.rows(for: exercise)[0], exercise: exercise)
        #expect(model.rest == nil)
    }

    @Test func comboRestsOnlyAfterItsLastExercise() async throws {
        let combo = TemplateDraft.BlockDraft(
            kind: .combo, attributes: [.power],
            exercises: [
                .init(name: "Salto", setsText: "3", targetText: "5"),
                .init(name: "Arremesso", setsText: "3", targetText: "5", restSeconds: 120),
            ])
        let (model, _, first) = try await makeModel(restSeconds: nil, blocks: [combo])
        model.toggle(model.rows(for: first)[0], exercise: first)
        #expect(model.rest == nil)
        let last = model.snapshot.blocks[0].exercises[1]
        model.toggle(model.rows(for: last)[0], exercise: last)
        #expect(model.rest?.duration == 120)
        model.skipRest()
    }

    @Test func fightRoundStoresRoundsAndLoads() async throws {
        let round = TemplateDraft.BlockDraft(
            kind: .fightRound, attributes: [.conditioning], durationMinutes: 6,
            exercises: [
                .init(name: "Swing Russo", setsText: "1", targetText: "máx")
            ])
        let (model, _, exercise) = try await makeModel(restSeconds: nil, blocks: [round])
        let block = model.snapshot.blocks[0]
        #expect(model.rows(for: exercise).isEmpty)
        await model.loadRound(block)
        model.setRoundsCompleted(3, block: block)
        model.setRoundWeight(24, exercise: exercise, block: block)
        model.startRoundTimer(block)
        #expect(model.roundTimers[block.blockId]?.duration == 360)
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.rounds[block.blockId]?.roundsCompleted == 3)
        #expect(model.roundWeight(exercise: exercise, block: block) == 24)
    }
}
