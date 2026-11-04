import Foundation
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct ProgressModelTests {
    /// Level 3 (412 XP): E is the current rank, D is next and starts when level 4 ends (864 XP).
    @Test func theLadderMarksTheCurrentAndTheNextRank() {
        let ladder = ProgressModel.ladder(totalXp: 412)
        #expect(ladder.map(\.rank.id) == [.e, .d, .c, .b, .a, .s])
        #expect(ladder.map(\.state) == [.current, .next(xpMissing: 452), .locked, .locked, .locked, .locked])
    }

    /// Past level 30 the top is reached: every rank before S is behind and S is the current one.
    @Test func pastLevelThirtyTheTopIsReached() {
        let ladder = ProgressModel.ladder(totalXp: 20_000)
        #expect(ladder.map(\.state) == [.reached, .reached, .reached, .reached, .reached, .current])
    }

    @Test func eachAttributeShowsItsChangeOverTheMonth() {
        let now: [Attribute: AttributeLevel] = [
            .conditioning: AttributeLevel(xp: 900, level: 7), .strength: AttributeLevel(xp: 400, level: 4),
        ]
        let before: [Attribute: AttributeLevel] = [.conditioning: AttributeLevel(xp: 500, level: 5)]
        let rows = ProgressModel.attributeRows(now: now, before: before)
        #expect(rows.map(\.attribute) == Attribute.allCases)
        let conditioning = rows.first { $0.attribute == .conditioning }
        #expect(conditioning?.level == 7)
        #expect(conditioning?.change == 2)
        #expect(conditioning?.levelBefore == 5)
        #expect(rows.first { $0.attribute == .strength }?.change == 3)
        let mobility = rows.first { $0.attribute == .mobility }
        #expect(mobility?.level == 1)
        #expect(mobility?.change == 0)
    }

    /// The model reads the records: 30 days ago is measured from `now`.
    @Test func loadComparesWithThirtyDaysAgo() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Leo")
        let start = Date(timeIntervalSince1970: 1_794_142_800)
        let run = ImportedActivity(
            id: UUID(), athleteId: athlete.id, source: "garmin", externalId: "run", activityType: "RUNNING",
            startedAt: start, durationSeconds: 3600, createdAt: start)
        try await database.writer.write { try run.insert($0) }
        let model = ProgressModel(database: database, athleteId: athlete.id)

        await model.load(now: start.addingTimeInterval(10 * 86_400))
        let recent = model.attributes.first { $0.attribute == .conditioning }
        #expect((model.history?.totalXp ?? 0) == 300)
        #expect(recent?.levelBefore == 1)
        #expect((recent?.change ?? 0) > 0)

        await model.load(now: start.addingTimeInterval(31 * 86_400))
        #expect(model.attributes.first { $0.attribute == .conditioning }?.change == 0)
    }
}
