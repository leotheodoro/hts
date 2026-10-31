import Foundation
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct DemoDataTests {
    /// `-HTSDemoActivities`: a run, a yoga session and a strength session recorded inside the demo workout (linked).
    @Test func demoActivitiesSeedOnce() async throws {
        let database = try AppDatabase.inMemory()
        let athlete = try await AthleteRepository(database).ensureLocalAthlete(displayName: "Atleta")
        try await DemoData.seed(database, athleteId: athlete.id)
        try await DemoData.seedActivities(database, athleteId: athlete.id)
        try await DemoData.seedActivities(database, athleteId: athlete.id)
        let entries = try await ProgressService(database).activities(athleteId: athlete.id)
        #expect(entries.count == 3)
        #expect(entries.filter { $0.linkedSessionId != nil }.count == 1)
    }
}
