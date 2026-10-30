import Foundation
import HTSAPI
import HTSDomain
import HTSPersistence
import Observation
import UserNotifications

/// App-wide state: the local database, the local athlete and the API client.
@MainActor
@Observable
final class AppModel {
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
    /// Bumped when data changes outside the screens (sync pulled rows, starter plan imported), so they reload.
    private(set) var dataVersion = 0

    /// The workout in progress, if any. It survives app restarts because it lives in the database.
    private(set) var activeSession: Session?
    /// Whether the active workout covers the tabs (false = minimized to the bottom bar).
    var showsActiveSession = false

    let apiConfiguration: APIConfiguration?
    let database: AppDatabase?
    private let api: APIClient?

    /// Asks for notification permission when a workout starts. Tests pass a no-op: the system prompt never answers
    /// in the test host.
    private let requestNotifications: @Sendable () async -> Void

    init(
        database: AppDatabase?, apiConfiguration: APIConfiguration?, databaseError: String? = nil,
        requestNotifications: @escaping @Sendable () async -> Void = {
            guard !TestHost.isRunningTests else { return }
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    ) {
        self.requestNotifications = requestNotifications
        self.database = database
        self.databaseError = databaseError
        self.apiConfiguration = apiConfiguration
        api = apiConfiguration.map { APIClient(configuration: $0) }
    }

    static func live() -> AppModel {
        let configuration = APIConfiguration.fromBundle()
        do {
            return AppModel(database: try AppDatabase.onDisk(), apiConfiguration: configuration)
        } catch {
            return AppModel(database: nil, apiConfiguration: configuration, databaseError: String(describing: error))
        }
    }

    func start() async {
        await loadLocalAthlete()
        #if DEBUG
            await checkHealth()
        #endif
    }

    func loadLocalAthlete() async {
        guard let database else { return }
        do {
            let athlete = try await AthleteRepository(database).ensureLocalAthlete(
                displayName: String(localized: "Atleta"))
            // Sync before the starter plan: a reinstall gets its arcs back from the server instead of a new copy.
            await sync(athleteId: athlete.id)
            if !TestHost.isRunningTests, let url = Bundle.main.url(forResource: "StarterPlan", withExtension: "json") {
                let plan = try StarterPlan.load(from: url)
                let added = try await plan.importMissing(into: database, athleteId: athlete.id, today: .today)
                if try await plan.fillVideos(into: database, athleteId: athlete.id) + added > 0 {
                    dataVersion += 1
                    await sync(athleteId: athlete.id)
                }
            }
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

    /// Pushes local changes and pulls the server's (docs/decisions/0026). Needs the API URL and token; without them
    /// the app simply stays local. The timeout is long because the free Render instance takes ~1 min to wake.
    func sync(athleteId: UUID? = nil) async {
        guard let database, let configuration = apiConfiguration, configuration.token != nil,
            let athleteId = athleteId ?? athlete?.id, syncState != .syncing
        else { return }
        syncState = .syncing
        do {
            let result = try await SyncService(
                database, transport: APIClient(configuration: configuration, timeout: 90)
            ).sync(athleteId: athleteId)
            syncState = .synced(.now)
            if result.pulled > 0 { dataVersion += 1 }
            if let id = athlete?.id, let refreshed = try await AthleteRepository(database).athlete(id: id) {
                athlete = refreshed
            }
        } catch {
            let host = configuration.baseURL.host() ?? "API"
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
                case .timedOut: String(localized: "Sem resposta de \(host) em 10 s.")
                case .unreachable: String(localized: "Não foi possível conectar a \(host).")
                case .other(let detail): detail
                }
            health = .offline(message)
        }
    }
}
