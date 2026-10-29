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
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Recrutamento", kanji: "試", weeks: weeks, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "A"), .init(origin: .new, name: "B")]),
            athleteId: athlete.id, seasonId: season.id)
        try await service.save(
            ArcDraft(
                name: "Forja", kanji: "試", weeks: 1, startDate: LocalDate("2026-11-09")!,
                templates: [.init(origin: .new, name: "C")]),
            athleteId: athlete.id, seasonId: season.id)
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
        // Each session fed FOR with 3 sets.
        #expect(completion.attributesBefore[.strength]?.xp == 30)
        #expect(completion.attributesAfter[.strength]?.xp == 60)
        #expect(completion.attributeGains == [.strength])

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
        let summaries = try await service.summaries(athleteId: athlete.id, seasonId: arc.seasonId)
        #expect(summaries.map(\.arc.status) == [.completed, .current])
    }
}

@Suite struct RecordsTests {
    @Test func bestLoadPerExerciseIgnoresDeletedSessions() async throws {
        let base = ProgressServiceTests()
        let (database, athlete, _, plans) = try await base.setUp()
        try await base.workout(database, plans[0], kg: 60, day: 0)
        let heavy = try await base.workout(database, plans[1], kg: Decimal(string: "72.5")!, day: 1)
        try await base.workout(database, plans[0], kg: 65, day: 2)

        var records = try await ProgressService(database).records(athleteId: athlete.id)
        #expect(records.map(\.exerciseName) == ["Supino"])
        #expect(records[0].weightKg == Decimal(string: "72.5"))
        #expect(records[0].sessionId == heavy.id)

        try await SessionRepository(database).delete(sessionId: heavy.id)
        records = try await ProgressService(database).records(athleteId: athlete.id)
        #expect(records[0].weightKg == 65)
    }
}

@Suite struct TitlesServiceTests {
    @Test func firstSessionAndArcCompletionUnlockTitles() async throws {
        let base = ProgressServiceTests()
        let (database, athlete, arc, plans) = try await base.setUp()
        let first = try await base.workout(database, plans[0], kg: 60, day: 0)
        var completion = try #require(try await ProgressService(database).completion(sessionId: first.id))
        #expect(completion.newTitles == [.firstSession])

        let second = try await base.workout(database, plans[1], kg: 60, day: 1)
        try await ArcService(database).completeIfDone(arcId: arc.id)
        completion = try #require(try await ProgressService(database).completion(sessionId: second.id))
        #expect(completion.newTitles == [.recruitmentComplete, .perfectWeek])

        let all = try await ProgressService(database).titles(athleteId: athlete.id)
        #expect(all.map(\.id) == [.firstSession, .recruitmentComplete, .perfectWeek])
    }
}

@Suite struct AttributeLevelsServiceTests {
    @Test func completedSetsFeedTheirBlockAttribute() async throws {
        let base = ProgressServiceTests()
        let (database, athlete, _, plans) = try await base.setUp()
        try await base.workout(database, plans[0], kg: 60, day: 0)
        let levels = try await ProgressService(database).attributeLevels(athleteId: athlete.id)
        #expect(levels[.strength]?.xp == 30)
        #expect(levels[.strength]?.level == 1)
        #expect(levels[.mobility]?.xp == 0)
    }
}

@Suite struct FightRoundProgressTests {
    @Test func roundsCountAsSetsAddVolumeAndFeedAttributes() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Torneio", kanji: "試", weeks: 1, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Muralha")]),
            athleteId: athlete.id, seasonId: season.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [
            .init(
                kind: .fightRound, attributes: [.conditioning], durationMinutes: 6,
                exercises: [
                    .init(name: "Swing Russo", setsText: "1", targetText: "máx")
                ])
        ]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)

        let sessions = SessionRepository(database)
        let session = try await sessions.start(filled, timeZone: TimeZone(identifier: "UTC")!)
        var round = try await sessions.round(for: session, block: session.planSnapshot.blocks[0])
        round.roundsCompleted = 4
        round.weights = [.init(exerciseId: filled.blocks[0].exercises[0].exercise.id, weightKg: 24)]
        try await sessions.save(round)
        _ = try await sessions.finish(sessionId: session.id)

        let completion = try #require(try await ProgressService(database).completion(sessionId: session.id))
        #expect(completion.progress.completedSets == 4)
        #expect(completion.progress.volumeKg == 96)
        #expect(completion.progress.xp == 80)  // 4 × 10 + 40, volume < 500
        let levels = try await ProgressService(database).attributeLevels(athleteId: athlete.id)
        #expect(levels[.conditioning]?.xp == 40)
    }
}
