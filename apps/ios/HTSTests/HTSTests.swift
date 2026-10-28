import HTSAPI
import HTSPersistence
import Testing

@testable import HTS

@MainActor
@Suite struct AppModelTests {
    @Test func createsTheLocalAthleteOnStart() async throws {
        let model = AppModel(database: try .inMemory(), apiConfiguration: nil)
        await model.loadLocalAthlete()
        #expect(model.athlete?.displayName == "Atleta")
        #expect(model.athlete?.defaultRestSeconds == 90)
    }

    @Test func reportsMissingAPIConfiguration() async {
        let model = AppModel(database: nil, apiConfiguration: nil)
        await model.checkHealth()
        guard case .offline = model.health else {
            Issue.record("expected offline, got \(model.health)")
            return
        }
    }

    @Test func debugBuildPointsToLocalAPI() {
        #expect(APIConfiguration.fromBundle()?.baseURL.absoluteString == "http://localhost:8787")
    }
}
