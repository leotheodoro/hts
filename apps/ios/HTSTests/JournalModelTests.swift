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
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Arco", kanji: "試", weeks: 4, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Treino")]),
            athleteId: athlete.id, seasonId: season.id)
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

    /// Two finished workouts (days 0 and 1, an hour each) and three Garmin activities: a strength session recorded
    /// inside the first workout, a run on day 0 at noon and a run on day 2.
    func journalWithActivities() async throws -> (AppDatabase, UUID, [UUID], linked: UUID) {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let service = ArcService(database)
        let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athlete.id)
        let arc = try await service.save(
            ArcDraft(
                name: "Arco", kanji: "試", weeks: 4, startDate: LocalDate("2026-11-02")!,
                templates: [.init(origin: .new, name: "Treino")]),
            athleteId: athlete.id, seasonId: season.id)
        let plan = try #require(try await PlanRepository(database).plan(arcId: arc.id))
        var draft = try #require(try await TemplateService(database).draft(templateId: plan.templates[0].template.id))
        draft.blocks = [.init(exercises: [.init(name: "Supino", setsText: "1", targetText: "8")])]
        try await TemplateService(database).save(draft)
        let filled = try #require(try await PlanRepository(database).plan(arcId: arc.id)?.templates.first)
        let sessions = SessionRepository(database)
        let t0 = Date(timeIntervalSince1970: 1_794_142_800)
        var ids: [UUID] = []
        for day in [0, 1] {
            let start = t0.addingTimeInterval(Double(day) * 86_400)
            let session = try await sessions.start(filled, now: start, timeZone: TimeZone(identifier: "UTC")!)
            for var set in try await sessions.sets(sessionId: session.id) {
                set.weightKg = 60
                set.reps = 8
                set.completed = true
                try await sessions.save(set)
            }
            ids.append(try await sessions.finish(sessionId: session.id, now: start.addingTimeInterval(3600)).id)
        }
        func activity(_ type: String, _ offset: TimeInterval, _ seconds: Int) async throws -> UUID {
            let start = t0.addingTimeInterval(offset)
            let activity = ImportedActivity(
                id: UUID(), athleteId: athlete.id, source: "garmin", externalId: UUID().uuidString,
                activityType: type, startedAt: start, durationSeconds: seconds, averageHeartRate: 140, calories: 300,
                createdAt: start)
            try await database.writer.write { try activity.insert($0) }
            return activity.id
        }
        let linked = try await activity("STRENGTH_TRAINING", 600, 1800)
        let noonRun = try await activity("RUNNING", 43_200, 2400)
        let lateRun = try await activity("RUNNING", 2 * 86_400, 2400)
        return (database, athlete.id, [lateRun, ids[1], noonRun, ids[0]], linked)
    }

    @Test func activitiesInterleaveWithSessionsByDate() async throws {
        let (database, athleteId, expected, _) = try await journalWithActivities()
        let model = JournalModel(database: database, athleteId: athleteId)
        await model.load()
        #expect(model.items.map(\.id) == expected)
    }

    @Test func linkedActivityIsNotAnItem() async throws {
        let (database, athleteId, order, linked) = try await journalWithActivities()
        let model = JournalModel(database: database, athleteId: athleteId)
        await model.load()
        #expect(!model.items.map(\.id).contains(linked))
        #expect(model.linkedActivities[order[3]]?.map(\.id) == [linked])
    }

    @Test func totalsCountOnlySessions() async throws {
        let (database, athleteId, _, _) = try await journalWithActivities()
        let model = JournalModel(database: database, athleteId: athleteId)
        await model.load()
        #expect(model.entries.count == 2)
        #expect(model.totalSets == 2)
        #expect(model.totalVolume == 960)
    }

    @Test func activitySummaryShowsDistancePaceAndHeartRate() {
        let start = Date(timeIntervalSince1970: 1_794_142_800)
        var run = ImportedActivity(
            id: UUID(), athleteId: UUID(), source: "garmin", externalId: "x", activityType: "RUNNING",
            startedAt: start, durationSeconds: 2405, distanceMeters: Decimal(string: "8200.4"), averageHeartRate: 152,
            createdAt: start)
        let pt = Locale(identifier: "pt_BR")
        // 2405 s over 8.2004 km = 293 s per km.
        #expect(run.summary(locale: pt) == "8,2 km · 40 min · 4:53 /km · FC 152")
        run.distanceMeters = nil
        run.averageHeartRate = nil
        #expect(run.summary(locale: pt) == "40 min")
    }

    @Test func everyLinkedActivityShowsInItsWorkout() async throws {
        let (database, athleteId, order, linked) = try await journalWithActivities()
        let workoutStart = Date(timeIntervalSince1970: 1_794_142_800)
        let warmUp = ImportedActivity(
            id: UUID(), athleteId: athleteId, source: "garmin", externalId: "warm-up", activityType: "RUNNING",
            startedAt: workoutStart.addingTimeInterval(60), durationSeconds: 480, createdAt: workoutStart)
        try await database.writer.write { try warmUp.insert($0) }
        let model = JournalModel(database: database, athleteId: athleteId)
        await model.load()
        #expect(Set((model.linkedActivities[order[3]] ?? []).map(\.id)) == [linked, warmUp.id])
        #expect(!model.items.map(\.id).contains(warmUp.id))
    }
}
