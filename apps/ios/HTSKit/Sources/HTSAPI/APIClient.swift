import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

/// Where the API lives. The app reads `HTSAPIBaseURL` from Info.plist, set per build configuration in
/// project.yml (Debug: http://localhost:8787).
public struct APIConfiguration: Sendable, Hashable {
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public static let infoPlistKey = "HTSAPIBaseURL"

    public static func fromBundle(_ bundle: Bundle = .main) -> APIConfiguration? {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            let url = URL(string: value), url.scheme != nil
        else { return nil }
        return APIConfiguration(baseURL: url)
    }
}

public struct HealthStatus: Sendable, Hashable {
    public let status: String
    public let version: String
}

public struct RemoteAthlete: Sendable, Hashable {
    public let id: UUID
    public let displayName: String
    public let defaultRestSeconds: Int
    public let createdAt: Date
    public let updatedAt: Date
}

public enum APIError: Error, Sendable {
    case unexpectedStatus(Int)
    case invalidResponse
}

/// Thin wrapper over the generated client (packages/contracts/openapi.json), so the app never sees generated
/// types.
public struct APIClient: Sendable {
    private let client: Client

    public init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.init(
            configuration: configuration,
            transport: URLSessionTransport(configuration: .init(session: session)))
    }

    init(configuration: APIConfiguration, transport: some ClientTransport) {
        client = Client(serverURL: configuration.baseURL, transport: transport)
    }

    public func health() async throws -> HealthStatus {
        switch try await client.getHealth() {
        case .ok(let ok):
            let body = try ok.body.json
            return HealthStatus(status: body.status.rawValue, version: body.version)
        case .undocumented(let status, _):
            throw APIError.unexpectedStatus(status)
        }
    }

    /// The athlete, or nil when the API does not know it (or it was deleted).
    public func athlete(id: UUID) async throws -> RemoteAthlete? {
        switch try await client.getAthlete(path: .init(id: id.uuidString.lowercased())) {
        case .ok(let ok):
            let body = try ok.body.json
            guard let id = UUID(uuidString: body.id) else { throw APIError.invalidResponse }
            return RemoteAthlete(
                id: id, displayName: body.displayName, defaultRestSeconds: body.defaultRestSeconds,
                createdAt: body.createdAt, updatedAt: body.updatedAt)
        case .notFound:
            return nil
        case .undocumented(let status, _):
            throw APIError.unexpectedStatus(status)
        }
    }
}
