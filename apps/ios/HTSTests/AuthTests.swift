import Foundation
import HTSAPI
import HTSDomain
import HTSPersistence
import Testing

@testable import HTS

/// The API as the app sees it, answering from fixed results.
final class FakeRemote: RemoteAPI, @unchecked Sendable {
    var loginResult: Result<AuthSession, any Error>
    var pullResult: Result<SyncChanges, any Error>
    private(set) var loginCalls = 0
    private(set) var logoutCalls = 0

    init(login: Result<AuthSession, any Error>, pull: Result<SyncChanges, any Error> = .success([:])) {
        loginResult = login
        pullResult = pull
    }

    func login(identifier: String, password: String) async throws -> AuthSession {
        loginCalls += 1
        return try loginResult.get()
    }

    func logout() async throws { logoutCalls += 1 }

    func push(_ changes: SyncChanges) async throws -> Int { 0 }

    func pull(athleteId: UUID, since: String?) async throws -> (cursor: String?, changes: SyncChanges) {
        (nil, try pullResult.get())
    }
}

@MainActor
@Suite struct AuthTests {
    static let athleteId = UUID(uuidString: "0190f2c4-0000-7000-8000-000000000001")!
    static let session = AuthSession(
        token: "tok-123", athleteId: athleteId,
        account: Account(
            id: UUID(uuidString: "0190f2c4-0000-7000-8000-000000000002")!, name: "Leonardo Theodoro",
            username: "leotheodoro", email: "simplespinheiro@gmail.com", avatarUrl: nil))

    /// What the server answers on the first pull: the athlete of the account.
    static let pulledAthlete: SyncChanges = [
        "athlete": [
            [
                "id": .string(athleteId.uuidString.lowercased()), "display_name": .string("Leonardo Theodoro"),
                "default_rest_seconds": .number(90), "created_at": .string("2026-10-30T12:00:00.000Z"),
                "updated_at": .string("2026-10-30T12:00:00.000Z"), "deleted_at": .null,
            ]
        ]
    ]

    func model(
        _ remote: FakeRemote, store: InMemorySessionStore = InMemorySessionStore(), database: AppDatabase? = nil
    ) throws -> AppModel {
        AppModel(
            database: try database ?? .inMemory(),
            apiConfiguration: APIConfiguration(baseURL: URL(string: "http://localhost:8787")!), sessionStore: store,
            remote: { _ in remote }, requestNotifications: {})
    }

    @Test func startsSignedOutWithoutASession() async throws {
        let app = try model(FakeRemote(login: .success(Self.session)))
        await app.start()
        #expect(app.authState == .signedOut)
        #expect(app.athlete == nil)
    }

    @Test func startsSignedInOfflineWithASavedSession() async throws {
        let remote = FakeRemote(
            login: .failure(URLError(.notConnectedToInternet)), pull: .failure(URLError(.notConnectedToInternet)))
        let store = InMemorySessionStore(Self.session)
        let app = try model(remote, store: store)
        await app.start()
        #expect(app.authState == .signedIn(Self.session))
        #expect(remote.loginCalls == 0)
    }

    @Test func signInSavesTheSessionAndPullsTheAthlete() async throws {
        let store = InMemorySessionStore()
        let app = try model(FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete)), store: store)
        await app.start()
        #expect(await app.signIn(identifier: "leotheodoro", password: "secret") == nil)
        #expect(app.authState == .signedIn(Self.session))
        #expect(app.athlete?.displayName == "Leonardo Theodoro")
        #expect(store.load() == Self.session)
    }

    @Test func wrongPasswordStaysSignedOut() async throws {
        let store = InMemorySessionStore()
        let app = try model(FakeRemote(login: .failure(APIError.invalidCredentials)), store: store)
        await app.start()
        #expect(await app.signIn(identifier: "leotheodoro", password: "nope") == .invalidCredentials)
        #expect(app.authState == .signedOut)
        #expect(store.load() == nil)
        let offline = try model(FakeRemote(login: .failure(URLError(.notConnectedToInternet))))
        #expect(await offline.signIn(identifier: "leotheodoro", password: "nope") == .offline)
        let limited = try model(FakeRemote(login: .failure(APIError.tooManyAttempts)))
        #expect(await limited.signIn(identifier: "leotheodoro", password: "nope") == .tooManyAttempts)
    }

    @Test func signOutKeepsLocalData() async throws {
        let database = try AppDatabase.inMemory()
        let remote = FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete))
        let store = InMemorySessionStore()
        let app = try model(remote, store: store, database: database)
        await app.start()
        _ = await app.signIn(identifier: "leotheodoro", password: "secret")
        await app.signOut()
        #expect(app.authState == .signedOut)
        #expect(store.load() == nil)
        #expect(remote.logoutCalls == 1)
        #expect(try await AthleteRepository(database).athlete(id: Self.athleteId) != nil)
    }

    @Test func unauthorizedSyncSignsOut() async throws {
        let database = try AppDatabase.inMemory()
        let remote = FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete))
        let store = InMemorySessionStore()
        let app = try model(remote, store: store, database: database)
        await app.start()
        _ = await app.signIn(identifier: "leotheodoro", password: "secret")
        remote.pullResult = .failure(APIError.unauthorized)
        await app.sync()
        #expect(app.authState == .signedOut)
        #expect(store.load() == nil)
        #expect(try await AthleteRepository(database).athlete(id: Self.athleteId) != nil)
    }

    @Test func freshInstallClearsTheKeychain() throws {
        let defaults = try #require(UserDefaults(suiteName: "AuthTests-\(UUID().uuidString)"))
        let store = InMemorySessionStore(Self.session)
        store.resetIfFreshInstall(defaults: defaults)
        #expect(store.load() == nil)
        #expect(defaults.bool(forKey: SessionStore.installedKey))
        try store.save(Self.session)
        store.resetIfFreshInstall(defaults: defaults)
        #expect(store.load() == Self.session)
    }
}
