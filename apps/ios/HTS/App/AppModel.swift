import Foundation
import HTSAPI
import HTSDomain
import HTSPersistence
import Observation
import UIKit
import UserNotifications

/// App-wide state: the login session, the local database, the athlete and the API client.
@MainActor
@Observable
final class AppModel {
    /// Whether someone is logged in on this device (docs/decisions/0031).
    enum AuthState: Equatable {
        /// Reading the saved session on launch.
        case checking
        case signedOut
        case signedIn(AuthSession)
    }

    enum SignInError: Equatable {
        case invalidCredentials
        case offline
        case tooManyAttempts
        case other(String)
    }

    /// What can go wrong in Minha conta (#144).
    enum AccountError: Equatable {
        case usernameTaken
        case emailTaken
        case wrongPassword
        case photoUnavailable
        case photoTooLarge
        case offline
        case other(String)
    }

    private(set) var authState: AuthState = .checking

    var session: AuthSession? {
        if case .signedIn(let session) = authState { session } else { nil }
    }

    enum HealthState: Equatable {
        case unknown
        case checking
        case online(version: String)
        case offline(String)
    }

    private(set) var athlete: Athlete?
    private(set) var databaseError: String?
    private(set) var health: HealthState = .unknown
    enum SyncState: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    private(set) var syncState: SyncState = .idle
    /// When this device last finished a sync (kept in SQLite), shown above Sair.
    private(set) var lastSyncedAt: Date?
    /// Bumped when data changes outside the screens (sync pulled rows, starter plan imported), so they reload.
    private(set) var dataVersion = 0

    /// The workout in progress, if any. It survives app restarts because it lives in the database.
    private(set) var activeSession: Session?
    /// Whether the active workout covers the tabs (false = minimized to the bottom bar).
    var showsActiveSession = false

    let apiConfiguration: APIConfiguration?
    let database: AppDatabase?
    private let api: APIClient?
    private let sessionStore: any SessionStoring
    /// Only the real app: tests and previews keep their in-memory session.
    private let resetsSessionOnFreshInstall: Bool
    /// The API with a session token (nil before login). Tests answer from a fake.
    private let remote: @Sendable (_ token: String?) -> (any RemoteAPI)?

    /// Asks for notification permission when a workout starts. Tests pass a no-op: the system prompt never answers
    /// in the test host.
    private let requestNotifications: @Sendable () async -> Void

    init(
        database: AppDatabase?, apiConfiguration: APIConfiguration?, databaseError: String? = nil,
        sessionStore: any SessionStoring = InMemorySessionStore(), resetsSessionOnFreshInstall: Bool = false,
        remote: (@Sendable (_ token: String?) -> (any RemoteAPI)?)? = nil,
        requestNotifications: @escaping @Sendable () async -> Void = {
            guard !TestHost.isRunningTests else { return }
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    ) {
        self.requestNotifications = requestNotifications
        self.database = database
        self.databaseError = databaseError
        self.apiConfiguration = apiConfiguration
        self.sessionStore = sessionStore
        self.resetsSessionOnFreshInstall = resetsSessionOnFreshInstall
        // Long timeout: the free Render instance takes ~1 min to wake, which is not the API being down.
        api = apiConfiguration.map { APIClient(configuration: $0, timeout: 60) }
        // The timeout is long because the free Render instance takes ~1 min to wake.
        self.remote =
            remote ?? { token in
                apiConfiguration.map {
                    APIClient(configuration: APIConfiguration(baseURL: $0.baseURL, token: token), timeout: 90)
                }
            }
    }

    static func live() -> AppModel {
        let configuration = APIConfiguration.fromBundle()
        let store = KeychainSessionStore()
        do {
            return AppModel(
                database: try AppDatabase.onDisk(), apiConfiguration: configuration, sessionStore: store,
                resetsSessionOnFreshInstall: true)
        } catch {
            return AppModel(
                database: nil, apiConfiguration: configuration, databaseError: String(describing: error),
                sessionStore: store, resetsSessionOnFreshInstall: true)
        }
    }

    /// Opens on the saved session without touching the network (it may be offline); the sync runs behind.
    func start() async {
        if resetsSessionOnFreshInstall {
            sessionStore.resetIfFreshInstall(protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable)
        }
        #if DEBUG
            if DemoData.usesLocalSession {
                await loadLocalAthlete()
                Task { await checkHealth() }
                return
            }
        #endif
        Task { await checkHealth() }
        guard let saved = sessionStore.load() else {
            authState = .signedOut
            return
        }
        authState = .signedIn(saved)
        await loadAthlete(saved.athleteId)
        if athlete == nil {
            await sync(athleteId: saved.athleteId)
            await loadAthlete(saved.athleteId)
        } else {
            Task { await sync() }
        }
    }

    /// Logs in, keeps the session and pulls the account's data before opening the app. Nil when it worked.
    func signIn(identifier: String, password: String) async -> SignInError? {
        guard let client = remote(nil) else { return .offline }
        do {
            let session = try await client.login(
                identifier: identifier.trimmingCharacters(in: .whitespaces), password: password)
            try sessionStore.save(session)
            // The app opens only after the first pull, so Home never shows up empty.
            await sync(session, athleteId: session.athleteId)
            authState = .signedIn(session)
            await loadAthlete(session.athleteId)
            return nil
        } catch APIError.invalidCredentials {
            return .invalidCredentials
        } catch APIError.tooManyAttempts {
            return .tooManyAttempts
        } catch {
            switch APIFailure(error) {
            case .timedOut, .unreachable: return .offline
            case .other(let detail): return .other(detail)
            }
        }
    }

    /// Changes name, username or e-mail (nil = unchanged) and keeps the new account in the session. A new name reaches
    /// the athlete through the next pull, which runs right away.
    func updateAccount(name: String?, username: String?, email: String?) async -> AccountError? {
        guard let session, let client = remote(session.token) else { return .offline }
        do {
            let account = try await client.updateAccount(name: name, username: username, email: email)
            var updated = session
            updated.account = account
            try sessionStore.save(updated)
            authState = .signedIn(updated)
            if name != nil { await sync() }
            return nil
        } catch {
            return Self.accountError(error)
        }
    }

    /// Sends the new photo (a JPEG already reduced by `AvatarImage`) and keeps the returned link in the session.
    func uploadAvatar(jpeg: Data) async -> AccountError? {
        guard let session, let client = remote(session.token) else { return .offline }
        do {
            var updated = session
            updated.account = try await client.uploadAvatar(jpeg: jpeg)
            try sessionStore.save(updated)
            authState = .signedIn(updated)
            return nil
        } catch {
            return Self.accountError(error)
        }
    }

    func changePassword(current: String, new: String) async -> AccountError? {
        guard let session, let client = remote(session.token) else { return .offline }
        do {
            try await client.changePassword(current: current, new: new)
            return nil
        } catch {
            return Self.accountError(error)
        }
    }

    private static func accountError(_ error: any Error) -> AccountError {
        switch error {
        case APIError.usernameTaken: .usernameTaken
        case APIError.emailTaken: .emailTaken
        case APIError.invalidCredentials: .wrongPassword
        case APIError.storageUnavailable: .photoUnavailable
        case APIError.photoTooLarge: .photoTooLarge
        default:
            switch APIFailure(error) {
            case .timedOut, .unreachable: .offline
            case .other(let detail): .other(detail)
            }
        }
    }

    /// Forgets the session here at once (the local data stays), then revokes it on the server when it can.
    func signOut() async {
        let token = session?.token
        signOutLocally()
        if let token, !token.isEmpty, let client = remote(token) {
            try? await client.logout()
        }
    }

    /// The session is the one in use, or the one being signed in (not yet in `authState`).
    private func isCurrent(_ session: AuthSession) -> Bool {
        self.session.map { $0.token == session.token } ?? true
    }

    private func signOutLocally() {
        sessionStore.clear()
        authState = .signedOut
        athlete = nil
        activeSession = nil
        showsActiveSession = false
        syncState = .idle
    }

    /// The athlete of the session from SQLite (after a sync it is the server's) and the workout in progress.
    private func loadAthlete(_ athleteId: UUID) async {
        guard let database else { return }
        do {
            lastSyncedAt = try await SyncService.lastSyncAt(database, athleteId: athleteId)
            athlete = try await AthleteRepository(database).athlete(id: athleteId)
            activeSession = try await SessionRepository(database).inProgress(athleteId: athleteId)
        } catch {
            databaseError = String(describing: error)
        }
    }

    /// A local athlete and a session that never reaches the API: DEBUG demos, screenshots and tests.
    func loadLocalAthlete() async {
        guard let database else { return }
        do {
            let athlete = try await AthleteRepository(database).ensureLocalAthlete(
                displayName: String(localized: "Atleta"))
            authState = .signedIn(
                AuthSession(
                    token: "", athleteId: athlete.id,
                    account: Account(
                        id: athlete.id, name: athlete.displayName, username: "local", email: "local@hts.local",
                        avatarUrl: nil)))
            #if DEBUG
                if DemoData.isRequested { try await DemoData.seed(database, athleteId: athlete.id) }
            #endif
            self.athlete = athlete
            activeSession = try await SessionRepository(database).inProgress(athleteId: athlete.id)
            #if DEBUG
                if UserDefaults.standard.bool(forKey: "HTSShowActiveSession"), activeSession != nil {
                    showsActiveSession = true
                }
                if DemoData.startsWorkout, activeSession == nil,
                    let arc = try await PlanRepository(database).currentArc(athleteId: athlete.id),
                    let plan = try await PlanRepository(database).plan(arcId: arc.id)?.templates.first
                {
                    await startWorkout(plan)
                }
            #endif
        } catch {
            databaseError = String(describing: error)
        }
    }

    func startWorkout(_ plan: TemplatePlan) async {
        guard let database else { return }
        do {
            activeSession = try await SessionRepository(database).start(plan)
            showsActiveSession = true
            // Ask for notifications now, not in the middle of the first rest.
            await requestNotifications()
        } catch {
            databaseError = String(describing: error)
        }
    }

    /// Called when the active workout is finished or discarded.
    func endWorkout() {
        activeSession = nil
        showsActiveSession = false
        Task { await sync() }
    }

    /// Pushes local changes and pulls the server's (docs/decisions/0026) with the session token. Without a session
    /// (or with the local one of demos) nothing is sent. A refused session signs out, keeping the local data.
    func sync(athleteId: UUID? = nil) async {
        guard let session else { return }
        await sync(session, athleteId: athleteId ?? session.athleteId)
    }

    private func sync(_ session: AuthSession, athleteId: UUID) async {
        guard let database, !session.token.isEmpty, let client = remote(session.token), syncState != .syncing
        else { return }
        syncState = .syncing
        do {
            let result = try await SyncService(database, transport: client).sync(athleteId: athleteId)
            lastSyncedAt = .now
            // A sync that outlived its session (Sair, then a new login) leaves the new state alone.
            guard isCurrent(session) else { return }
            syncState = .synced(.now)
            if result.pulled > 0 { dataVersion += 1 }
            if let id = athlete?.id, let refreshed = try await AthleteRepository(database).athlete(id: id) {
                athlete = refreshed
            }
        } catch APIError.unauthorized {
            // Only the session that made the request: a late answer must not sign out a newer login.
            if self.session?.token == session.token { signOutLocally() }
        } catch {
            guard isCurrent(session) else { return }
            let host = apiConfiguration?.baseURL.host() ?? "API"
            let message =
                switch APIFailure(error) {
                case .timedOut: String(localized: "Sem resposta de \(host).")
                case .unreachable: String(localized: "Sem conexão com \(host). Os dados ficam no aparelho.")
                case .other(let detail): detail
                }
            syncState = .failed(message)
        }
    }

    func updateAthlete(_ athlete: Athlete) async {
        guard let database else { return }
        do {
            self.athlete = try await AthleteRepository(database).update(athlete)
        } catch {
            databaseError = String(describing: error)
        }
    }

    func checkHealth() async {
        guard let api else {
            health = .offline(String(localized: "URL da API não configurada"))
            return
        }
        health = .checking
        do {
            health = .online(version: try await api.health().version)
        } catch {
            let host = apiConfiguration?.baseURL.host() ?? "API"
            let message =
                switch APIFailure(error) {
                case .timedOut: String(localized: "Sem resposta de \(host) em 60 s.")
                case .unreachable: String(localized: "Não foi possível conectar a \(host).")
                case .other(let detail): detail
                }
            health = .offline(message)
        }
    }
}
