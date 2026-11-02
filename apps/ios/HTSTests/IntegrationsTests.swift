import Foundation
import HTSAPI
import HTSPersistence
import Testing

@testable import HTS

/// Perfil > Integrações (spec 2026-10-31): status from the API, connect unavailable until Garmin approves, disconnect.
@MainActor
@Suite struct IntegrationsTests {
    func signedIn(_ remote: FakeRemote) async throws -> AppModel {
        let app = AppModel(
            database: try .inMemory(),
            apiConfiguration: APIConfiguration(baseURL: URL(string: "http://localhost:8787")!),
            sessionStore: InMemorySessionStore(AuthTests.session), remote: { _ in remote }, requestNotifications: {})
        await app.start()
        return app
    }

    @Test func statusComesFromTheAPI() async throws {
        let remote = FakeRemote(login: .success(AuthTests.session))
        let last = Date(timeIntervalSince1970: 1_793_602_800)
        remote.integrationsResult = .success([
            IntegrationStatus(provider: "garmin", connected: true, connectedAt: last, lastActivityAt: last)
        ])
        let app = try await signedIn(remote)
        await app.loadIntegrations()
        #expect(app.garminStatus?.connected == true)
        #expect(app.garminStatus?.lastActivityAt == last)
    }

    @Test func connectReportsUnavailableWithoutTheClient() async throws {
        let remote = FakeRemote(login: .success(AuthTests.session))
        let app = try await signedIn(remote)
        #expect(await app.garminLoginPage() == .failure(.unavailable))
        remote.connectResult = .failure(URLError(.notConnectedToInternet))
        #expect(await app.garminLoginPage() == .failure(.offline))
    }

    @Test func connectAnswersTheGarminLoginPage() async throws {
        let remote = FakeRemote(login: .success(AuthTests.session))
        let page = URL(string: "https://connect.garmin.com/oauth2Confirm?state=s")!
        remote.connectResult = .success(page)
        let app = try await signedIn(remote)
        #expect(await app.garminLoginPage() == .success(page))
    }

    @Test func readsTheStatusTheLoginSendsBack() {
        let back = { (status: String) in
            GarminLogin.status(from: URL(string: "hardtosubmit://integrations/garmin?status=\(status)")!)
        }
        #expect(back("connected") == .connected)
        #expect(back("denied") == .denied)
        #expect(back("error") == .failed)
        #expect(GarminLogin.status(from: URL(string: "hardtosubmit://integrations/garmin")!) == .failed)
    }

    @Test func disconnectClearsTheStatus() async throws {
        let remote = FakeRemote(login: .success(AuthTests.session))
        remote.integrationsResult = .success([IntegrationStatus(provider: "garmin", connected: true)])
        let app = try await signedIn(remote)
        await app.loadIntegrations()
        #expect(await app.disconnectGarmin() == nil)
        #expect(remote.disconnectCalls == 1)
        #expect(app.garminStatus?.connected == false)
    }
}
