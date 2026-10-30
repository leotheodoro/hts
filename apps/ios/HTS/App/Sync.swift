import HTSAPI
import HTSDomain
import HTSPersistence

/// What the app needs from the API: login, logout and the sync (docs/decisions/0031). Tests answer with a fake.
protocol RemoteAPI: SyncTransport {
    func login(identifier: String, password: String) async throws -> AuthSession
    func logout() async throws
}

// The generated API client is the sync transport. Declared here so HTSAPI and HTSPersistence stay independent.
extension APIClient: @retroactive SyncTransport {}
extension APIClient: RemoteAPI {}
