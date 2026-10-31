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
    /// Runs inside every pull, before it answers.
    var onPull: (@Sendable () async -> Void)?
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

    var updateResult: Result<Account, any Error> = .failure(APIError.invalidResponse)
    var passwordResult: Result<Void, any Error> = .success(())

    func updateAccount(name: String?, username: String?, email: String?) async throws -> Account {
        try updateResult.get()
    }

    func changePassword(current: String, new: String) async throws { try passwordResult.get() }

    var avatarResult: Result<Account, any Error> = .failure(APIError.storageUnavailable)
    private(set) var uploaded: Data?

    func uploadAvatar(jpeg: Data) async throws -> Account {
        uploaded = jpeg
        return try avatarResult.get()
    }

    var integrationsResult: Result<[IntegrationStatus], any Error> = .success([
        IntegrationStatus(provider: "garmin", connected: false)
    ])
    var connectResult: Result<URL, any Error> = .failure(APIError.garminUnavailable)
    private(set) var disconnectCalls = 0

    func integrations() async throws -> [IntegrationStatus] { try integrationsResult.get() }
    func connectGarmin() async throws -> URL { try connectResult.get() }
    func disconnectGarmin() async throws { disconnectCalls += 1 }

    func push(_ changes: SyncChanges) async throws -> Int { 0 }

    func pull(athleteId: UUID, since: String?) async throws -> (cursor: String?, changes: SyncChanges) {
        await onPull?()
        return (nil, try pullResult.get())
    }
}

/// Opens once; everyone waiting goes on.
actor Gate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

final class Box<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) { self.value = value }
}

@MainActor
@Suite struct AuthTests {
    static let athleteId = UUID(uuidString: "0190f2c4-0000-7000-8000-000000000001")!
    static let session = AuthSession(
        token: "tok-123", athleteId: athleteId,
        account: Account(
            id: UUID(uuidString: "0190f2c4-0000-7000-8000-000000000002")!, name: "Leonardo Theodoro",
            username: "leotheodoro", email: "leo@example.com", avatarUrl: nil))

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
        store.resetIfFreshInstall(defaults: defaults, protectedDataAvailable: true)
        #expect(store.load() == nil)
        #expect(defaults.bool(forKey: SessionStore.installedKey))
        try store.save(Self.session)
        store.resetIfFreshInstall(defaults: defaults, protectedDataAvailable: true)
        #expect(store.load() == Self.session)
    }

    @Test func signInOpensTheAppOnlyAfterThePull() async throws {
        let remote = FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete))
        let app = try model(remote)
        await app.start()
        let seen = Box<AppModel.AuthState?>(nil)
        remote.onPull = { await MainActor.run { seen.value = app.authState } }
        #expect(await app.signIn(identifier: "leotheodoro", password: "secret") == nil)
        #expect(seen.value == .signedOut)
        #expect(app.authState == .signedIn(Self.session))
    }

    @Test func aLateUnauthorizedFromAnOldSessionKeepsTheNewLogin() async throws {
        let old = FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete))
        let newer = AuthSession(token: "tok-new", athleteId: Self.athleteId, account: Self.session.account)
        let fresh = FakeRemote(login: .success(newer))
        let store = InMemorySessionStore(Self.session)
        let oldToken = Self.session.token
        let app = AppModel(
            database: try .inMemory(),
            apiConfiguration: APIConfiguration(baseURL: URL(string: "http://localhost:8787")!), sessionStore: store,
            remote: { token in token == oldToken ? old : fresh }, requestNotifications: {})
        await app.start()

        let reached = Gate()
        let release = Gate()
        old.pullResult = .failure(APIError.unauthorized)
        old.onPull = {
            await reached.open()
            await release.wait()
        }
        let stale = Task { await app.sync() }
        await reached.wait()
        await app.signOut()
        #expect(await app.signIn(identifier: "leotheodoro", password: "secret") == nil)
        await release.open()
        await stale.value

        #expect(app.authState == .signedIn(newer))
        #expect(store.load() == newer)
    }

    @Test func aPrewarmedLaunchDoesNotLookLikeAFreshInstall() throws {
        let defaults = try #require(UserDefaults(suiteName: "AuthTests-\(UUID().uuidString)"))
        let store = InMemorySessionStore(Self.session)
        store.resetIfFreshInstall(defaults: defaults, protectedDataAvailable: false)
        #expect(store.load() == Self.session)
        #expect(!defaults.bool(forKey: SessionStore.installedKey))
    }

    @Test func editingTheAccountKeepsTheNewDataInTheSession() async throws {
        let remote = FakeRemote(login: .success(Self.session), pull: .success(Self.pulledAthlete))
        let store = InMemorySessionStore(Self.session)
        let app = try model(remote, store: store)
        await app.start()
        var renamed = Self.session.account
        renamed.name = "Leo Novo"
        renamed.username = "leo"
        remote.updateResult = .success(renamed)
        #expect(await app.updateAccount(name: "Leo Novo", username: "leo", email: nil) == nil)
        #expect(app.session?.account == renamed)
        #expect(store.load()?.account == renamed)
        #expect(store.load()?.token == Self.session.token)

        remote.updateResult = .failure(APIError.usernameTaken)
        #expect(await app.updateAccount(name: nil, username: "taken", email: nil) == .usernameTaken)
        remote.updateResult = .failure(APIError.emailTaken)
        #expect(await app.updateAccount(name: nil, username: nil, email: "x@y.z") == .emailTaken)
    }

    @Test func changingThePasswordReportsAWrongCurrentOne() async throws {
        let remote = FakeRemote(login: .success(Self.session))
        let app = try model(remote, store: InMemorySessionStore(Self.session))
        await app.start()
        #expect(await app.changePassword(current: "old", new: "new-password") == nil)
        remote.passwordResult = .failure(APIError.invalidCredentials)
        #expect(await app.changePassword(current: "nope", new: "new-password") == .wrongPassword)
    }

    @Test func aNewPhotoGoesUpAndStaysInTheSession() async throws {
        let remote = FakeRemote(login: .success(Self.session))
        let store = InMemorySessionStore(Self.session)
        let app = try model(remote, store: store)
        await app.start()
        var withPhoto = Self.session.account
        withPhoto.avatarUrl = "https://b.test/a.jpg"
        remote.avatarResult = .success(withPhoto)
        #expect(await app.uploadAvatar(jpeg: Data([0xFF, 0xD8, 0xFF])) == nil)
        #expect(remote.uploaded == Data([0xFF, 0xD8, 0xFF]))
        #expect(store.load()?.account.avatarUrl == "https://b.test/a.jpg")
        remote.avatarResult = .failure(APIError.storageUnavailable)
        #expect(await app.uploadAvatar(jpeg: Data([0xFF])) == .photoUnavailable)
    }
}
