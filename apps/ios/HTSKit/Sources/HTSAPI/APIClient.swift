import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Where the API lives. The app reads `HTSAPIBaseURL` from Info.plist, set per build configuration in
/// project.yml (Debug: http://localhost:8787).
public struct APIConfiguration: Sendable, Hashable {
    public var baseURL: URL
    /// Fixed bearer token for /v1 (docs/decisions/0024). Nil when not configured.
    public var token: String?

    public init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }

    public static let infoPlistKey = "HTSAPIBaseURL"
    public static let tokenInfoPlistKey = "HTSAPIToken"

    public static func fromBundle(_ bundle: Bundle = .main) -> APIConfiguration? {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            let url = URL(string: value), url.scheme != nil
        else { return nil }
        let token = (bundle.object(forInfoDictionaryKey: tokenInfoPlistKey) as? String).flatMap {
            $0.isEmpty || $0.hasPrefix("$(") ? nil : $0
        }
        return APIConfiguration(baseURL: url, token: token)
    }
}

/// Adds `Authorization: Bearer <token>` to every request.
struct BearerTokenMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
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

/// Short reason for a failed request, for the UI.
public enum APIFailure: Equatable, Sendable {
    case timedOut
    case unreachable
    case other(String)

    public init(_ error: any Error) {
        let underlying = (error as? ClientError)?.underlyingError ?? error
        switch (underlying as? URLError)?.code {
        case .timedOut?: self = .timedOut
        case .cannotFindHost?, .cannotConnectToHost?, .notConnectedToInternet?, .networkConnectionLost?,
            .dnsLookupFailed?:
            self = .unreachable
        default: self = .other(String(describing: underlying))
        }
    }
}

/// Thin wrapper over the generated client (packages/contracts/openapi.json), so the app never sees generated
/// types.
public struct APIClient: Sendable {
    private let client: Client

    /// Requests give up after `timeout` seconds instead of URLSession's 60.
    public init(configuration: APIConfiguration, timeout: TimeInterval = 10) {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = timeout
        sessionConfiguration.waitsForConnectivity = false
        self.init(
            configuration: configuration,
            transport: URLSessionTransport(
                configuration: .init(session: URLSession(configuration: sessionConfiguration))))
    }

    init(configuration: APIConfiguration, transport: some ClientTransport) {
        client = Client(
            serverURL: configuration.baseURL, transport: transport,
            middlewares: configuration.token.map { [BearerTokenMiddleware(token: $0)] } ?? [])
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
        case .unauthorized:
            throw APIError.unexpectedStatus(401)
        case .undocumented(let status, _):
            throw APIError.unexpectedStatus(status)
        }
    }
}
