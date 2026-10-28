import Foundation
import HTSAPI
import HTSPersistence
import Observation

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

    let apiConfiguration: APIConfiguration?
    private let database: AppDatabase?
    private let api: APIClient?

    init(database: AppDatabase?, apiConfiguration: APIConfiguration?, databaseError: String? = nil) {
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
            athlete = try await AthleteRepository(database).ensureLocalAthlete(
                displayName: String(localized: "Atleta"))
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
            health = .offline(error.localizedDescription)
        }
    }
}
