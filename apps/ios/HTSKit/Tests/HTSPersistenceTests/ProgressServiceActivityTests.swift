import Foundation
import HTSDomain
import Testing

@testable import HTSPersistence

/// Garmin activities in the progress (spec 2026-10-31): extra XP and attributes, none when linked to a workout.
extension ProgressServiceTests {
    @discardableResult
    func activity(
        _ database: AppDatabase, _ athlete: Athlete, type: String = "RUNNING", at start: Date, seconds: Int,
        deleted: Bool = false
    ) async throws -> ImportedActivity {
        let activity = ImportedActivity(
            id: UUIDv7.make(at: start), athleteId: athlete.id, source: "garmin", externalId: UUID().uuidString,
            activityType: type, startedAt: start, durationSeconds: seconds, createdAt: start,
            deletedAt: deleted ? start : nil)
        try await database.writer.write { try activity.insert($0) }
        return activity
    }

    @Test func historyCountsAnUnlinkedRun() async throws {
        let (database, athlete, _, plans) = try await setUp()
        try await workout(database, plans[0], kg: 60, day: 0)
        try await activity(database, athlete, at: t0.addingTimeInterval(86_400), seconds: 2400)
        let service = ProgressService(database)
        // 3 sets 30 + session 40 + volume 2, plus a 40 min run.
        #expect(try await service.history(athleteId: athlete.id).history.totalXp == 72 + 200)
        #expect(try await service.attributeLevels(athleteId: athlete.id)[.conditioning]?.xp == 100)
        #expect(try await service.activities(athleteId: athlete.id).first?.linkedSessionId == nil)
    }

    @Test func aRunInsideTheWorkoutIsLinked() async throws {
        let (database, athlete, _, plans) = try await setUp()
        let session = try await workout(database, plans[0], kg: 60, day: 0)
        try await activity(database, athlete, type: "STRENGTH_TRAINING", at: t0.addingTimeInterval(600), seconds: 1800)
        let service = ProgressService(database)
        let entries = try await service.activities(athleteId: athlete.id)
        #expect(entries.first?.linkedSessionId == session.id)
        #expect(entries.first?.xp.xp == 150)
        #expect(try await service.history(athleteId: athlete.id).history.totalXp == 72)
        #expect(try await service.attributeLevels(athleteId: athlete.id)[.strength]?.xp == 30)
    }

    @Test func unlinksWhenTheSessionIsDeleted() async throws {
        let (database, athlete, _, plans) = try await setUp()
        let session = try await workout(database, plans[0], kg: 60, day: 0)
        try await activity(database, athlete, at: t0.addingTimeInterval(600), seconds: 1800)
        try await SessionRepository(database).delete(sessionId: session.id)
        let service = ProgressService(database)
        #expect(try await service.activities(athleteId: athlete.id).first?.linkedSessionId == nil)
        #expect(try await service.history(athleteId: athlete.id).history.totalXp == 150)
    }

    @Test func deletedActivitiesDoNotCount() async throws {
        let (database, athlete, _, plans) = try await setUp()
        try await workout(database, plans[0], kg: 60, day: 0)
        try await activity(database, athlete, at: t0.addingTimeInterval(86_400), seconds: 2400, deleted: true)
        let service = ProgressService(database)
        #expect(try await service.activities(athleteId: athlete.id).isEmpty)
        #expect(try await service.history(athleteId: athlete.id).history.totalXp == 72)
    }

    @Test func completionCountsActivitiesBeforeTheWorkout() async throws {
        let (database, athlete, _, plans) = try await setUp()
        try await activity(database, athlete, at: t0.addingTimeInterval(-86_400), seconds: 2400)
        let session = try await workout(database, plans[0], kg: 60, day: 0)
        try await activity(database, athlete, at: t0.addingTimeInterval(86_400), seconds: 2400)
        let completion = try #require(try await ProgressService(database).completion(sessionId: session.id))
        #expect(completion.before.totalXp == 200)
        #expect(completion.after.totalXp == 272)
        #expect(completion.attributesBefore[.conditioning]?.xp == 100)
        #expect(completion.attributesAfter[.conditioning]?.xp == 100)
    }
}
