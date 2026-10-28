import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct ProgressServiceTests {
    let utc = TimeZone(identifier: "UTC")!
    let t0 = Date(timeIntervalSince1970: 1_793_000_000)

    /// Arc of 1 template × 1 week (2 sessions total with templates A, B) and Supino 3 × 8.
    func setUp(weeks: Int = 1) async throws -> (AppDatabase, Athlete, Arc, [TemplatePlan]) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let saga = try await service.saga(athleteId: athlete.id, year: 2026)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", weeks: weeks, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "A"), .init(origin: .new, name: "B")]),
            athleteId: athlete.id, sagaId: saga.id)
        try await service.save(
            ArcDraft(
                name: "Forja", weeks: 1, startDate: LocalDate("2026-11-09")!,
                templates: [.init(origin: .new, name: "C")]),
            athleteId: athlete.id, sagaId: saga.id)
        var plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        for template in plan.templates {
            var draft = try #require(try await TemplateService(database).draft(templateId: template.template.id))
            draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "3", targetText: "8")])]
            try await TemplateService(database).save(draft)
        }
        plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        return (database, athlete, arc, plan.templates)
    }

    /// Runs a whole session: every set at `kg` × 8, checked.
    @discardableResult
    func workout(_ database: AppDatabase, _ plan: TemplatePlan, kg: Decimal, day: Int) async throws -> Session {
        let repository = SessionRepository(database)
        let start = t0.addingTimeInterval(Double(day) * 86_400)
        let session = try await repository.start(plan, now: start, timeZone: utc)
        for var set in try await repository.sets(sessionId: session.id) {
            set.weightKg = kg
            set.reps = 8
            set.completed = true
            try await repository.save(set)
        }
        return try await repository.finish(sessionId: session.id, now: start.addingTimeInterval(3600))
    }

    @Test func completionShowsXpVolumeAndNewRecords() async throws {
        let (database, athlete, _, plans) = try await setUp()
        try await workout(database, plans[0], kg: 60, day: 0)
        let second = try await workout(database, plans[1], kg: Decimal(string: "62.5")!, day: 1)

        let completion = try #require(try await ProgressService(database).completion(sessionId: second.id))
        #expect(completion.progress.completedSets == 3)
        #expect(completion.progress.volumeKg == 1500)
        #expect(completion.recordNames == ["Supino"])
        // 3 sets 30 + session 40 + record 25 + volume 3.
        #expect(completion.progress.xp == 98)
        #expect(completion.before.totalXp == 72)
        #expect(completion.after.totalXp == 170)
        #expect(completion.leveledUp)
        #expect(!completion.rankedUp)

        let (sessions, history) = try await ProgressService(database).history(athleteId: athlete.id)
        #expect(sessions.count == 2)
        #expect(history.totalXp == 170)
    }

    @Test func deletingASessionRecomputesRecordsAndXp() async throws {
        let (database, athlete, _, plans) = try await setUp()
        let first = try await workout(database, plans[0], kg: 60, day: 0)
        let second = try await workout(database, plans[1], kg: 70, day: 1)
        try await SessionRepository(database).delete(sessionId: first.id)

        let completion = try #require(try await ProgressService(database).completion(sessionId: second.id))
        #expect(completion.recordNames.isEmpty)
        #expect(try await ProgressService(database).history(athleteId: athlete.id).history.totalXp == 73)
    }

    @Test func finishingTheLastSessionCompletesTheArcAndPromotesTheNext() async throws {
        let (database, athlete, arc, plans) = try await setUp()
        let service = ArcService(database)
        try await workout(database, plans[0], kg: 60, day: 0)
        #expect(try await service.completeIfDone(arcId: arc.id) == nil)
        try await workout(database, plans[1], kg: 60, day: 1)
        let next = try #require(try await service.completeIfDone(arcId: arc.id))
        #expect(next.name == "Forja")
        #expect(next.status == .current)
        #expect(try await PlanRepository(database).currentArc(athleteId: athlete.id)?.id == next.id)
        let summaries = try await service.summaries(athleteId: athlete.id, sagaId: arc.sagaId)
        #expect(summaries.map(\.arc.status) == [.completed, .current])
    }
}
