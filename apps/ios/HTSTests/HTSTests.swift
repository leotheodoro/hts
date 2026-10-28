import Testing

@testable import HTS

@Suite struct AppSmokeTests {
    @Test func appModuleLoads() {
        #expect(Bool(true))
    }
}
