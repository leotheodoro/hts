import Foundation
import HTSDomain
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Where the API lives. The app reads `HTSAPIBaseURL` from Info.plist, set per build configuration in
/// project.yml (Debug: http://localhost:8787).
public struct APIConfiguration: Sendable, Hashable {
    public var baseURL: URL
    /// Session token from the login (docs/decisions/0031). Nil before logging in.
    public var token: String?

    public init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }

    public static let infoPlistKey = "HTSAPIBaseURL"

    public static func fromBundle(_ bundle: Bundle = .main) -> APIConfiguration? {
        guard let value = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
            let url = URL(string: value), url.scheme != nil
        else { return nil }
        return APIConfiguration(baseURL: url)
    }
}

/// The logged-in account (docs/decisions/0031).
public struct Account: Codable, Sendable, Hashable {
    public var id: UUID
    public var name: String
    public var username: String
    public var email: String
    public var avatarUrl: String?

    public init(id: UUID, name: String, username: String, email: String, avatarUrl: String?) {
        self.id = id
        self.name = name
        self.username = username
        self.email = email
        self.avatarUrl = avatarUrl
    }
}

/// What a login returns and the device keeps: the token, the athlete it reaches and the account.
public struct AuthSession: Codable, Sendable, Hashable {
    public var token: String
    public var athleteId: UUID
    public var account: Account

    public init(token: String, athleteId: UUID, account: Account) {
        self.token = token
        self.athleteId = athleteId
        self.account = account
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

public enum APIError: Error, Sendable, Equatable {
    case unexpectedStatus(Int)
    case invalidResponse
    /// Login: unknown user or wrong password (the API does not say which).
    case invalidCredentials
    /// Login: too many failed attempts; try again in a few minutes.
    case tooManyAttempts
    /// A protected route refused the session (missing, unknown or revoked).
    case unauthorized
    /// Minha conta: another account already uses this username or e-mail.
    case usernameTaken
    case emailTaken
    /// Photo upload: the server has no bucket configured, or the photo is over 2 MB.
    case storageUnavailable
    case photoTooLarge
    /// Integrations: the Garmin access is not approved yet, so there is no login to open.
    case garminUnavailable
}

/// One platform on the Integrations page: whether the account is connected and when the last activity arrived.
public struct IntegrationStatus: Sendable, Hashable {
    public var provider: String
    public var connected: Bool
    public var connectedAt: Date?
    public var lastActivityAt: Date?

    public init(provider: String, connected: Bool, connectedAt: Date? = nil, lastActivityAt: Date? = nil) {
        self.provider = provider
        self.connected = connected
        self.connectedAt = connectedAt
        self.lastActivityAt = lastActivityAt
    }
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
        // The API writes dates with milliseconds ("2026-11-02T12:00:00.123Z"), like the database.
        client = Client(
            serverURL: configuration.baseURL, configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: transport,
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
            throw APIError.unauthorized
        case .forbidden:
            throw APIError.unexpectedStatus(403)
        case .undocumented(let status, _):
            throw APIError.unexpectedStatus(status)
        }
    }

    // MARK: Auth (docs/decisions/0031)

    /// Logs in with username or e-mail. The returned session lasts until `logout()`.
    public func login(identifier: String, password: String) async throws -> AuthSession {
        switch try await client.login(body: .json(.init(identifier: identifier, password: password))) {
        case .ok(let ok):
            let body = try ok.body.json
            guard let athleteId = UUID(uuidString: body.athleteId), let accountId = UUID(uuidString: body.account.id)
            else { throw APIError.invalidResponse }
            return AuthSession(
                token: body.token, athleteId: athleteId,
                account: Account(
                    id: accountId, name: body.account.name, username: body.account.username,
                    email: body.account.email, avatarUrl: body.account.avatarUrl))
        case .unauthorized: throw APIError.invalidCredentials
        case .tooManyRequests: throw APIError.tooManyAttempts
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// Revokes the session of this client's token.
    public func logout() async throws {
        switch try await client.logout() {
        case .noContent: return
        case .unauthorized: throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    // MARK: Account (#141)

    /// Changes the fields that are not nil and returns the account as the server keeps it.
    public func updateAccount(name: String?, username: String?, email: String?) async throws -> Account {
        let body = Operations.UpdateAccount.Input.Body.JsonPayload(name: name, username: username, email: email)
        switch try await client.updateAccount(body: .json(body)) {
        case .ok(let ok): return try Self.account(try ok.body.json.account)
        case .conflict(let conflict):
            throw try conflict.body.json.error == "email_taken" ? APIError.emailTaken : APIError.usernameTaken
        case .unauthorized: throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// The current password is required; the server signs the other devices out.
    public func changePassword(current: String, new: String) async throws {
        let body = Operations.ChangePassword.Input.Body.JsonPayload(currentPassword: current, newPassword: new)
        switch try await client.changePassword(body: .json(body)) {
        case .noContent: return
        case .unauthorized(let refused):
            throw try refused.body.json.error == "invalid_credentials"
                ? APIError.invalidCredentials : APIError.unauthorized
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// Replaces the account photo with a JPEG (up to 2 MB) and returns the account with its new signed link.
    public func uploadAvatar(jpeg: Data) async throws -> Account {
        switch try await client.uploadAvatar(body: .jpeg(HTTPBody(jpeg))) {
        case .ok(let ok): return try Self.account(try ok.body.json.account)
        case .badRequest: throw APIError.unexpectedStatus(400)
        case .unauthorized: throw APIError.unauthorized
        case .contentTooLarge: throw APIError.photoTooLarge
        case .serviceUnavailable: throw APIError.storageUnavailable
        case .badGateway: throw APIError.unexpectedStatus(502)
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    // MARK: Integrations (spec 2026-10-31)

    public func integrations() async throws -> [IntegrationStatus] {
        switch try await client.listIntegrations() {
        case .ok(let ok):
            let date = { (text: String?) in
                try text.map {
                    try Date($0, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
                }
            }
            return try ok.body.json.integrations.map {
                IntegrationStatus(
                    provider: $0.provider.rawValue, connected: $0.connected, connectedAt: try date($0.connectedAt),
                    lastActivityAt: try date($0.lastActivityAt))
            }
        case .unauthorized: throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// The Garmin login page to open. Until the access is approved, the API answers `garminUnavailable`.
    public func connectGarmin() async throws -> URL {
        switch try await client.connectGarmin() {
        case .ok(let ok):
            guard let url = URL(string: try ok.body.json.url) else { throw APIError.invalidResponse }
            return url
        case .unauthorized: throw APIError.unauthorized
        case .serviceUnavailable: throw APIError.garminUnavailable
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    public func disconnectGarmin() async throws {
        switch try await client.disconnectGarmin() {
        case .noContent: return
        case .unauthorized: throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    private static func account(_ body: Components.Schemas.Account) throws -> Account {
        guard let id = UUID(uuidString: body.id) else { throw APIError.invalidResponse }
        return Account(
            id: id, name: body.name, username: body.username, email: body.email, avatarUrl: body.avatarUrl)
    }

    // MARK: Sync (docs/decisions/0026)

    /// Sends rows changed on the device. Returns how many the server applied.
    public func push(_ changes: SyncChanges) async throws -> Int {
        let body = Operations.SyncPush.Input.Body.JsonPayload(changes: try Self.convert(changes))
        switch try await client.syncPush(body: .json(body)) {
        case .ok(let ok): return try ok.body.json.applied
        case .badRequest: throw APIError.unexpectedStatus(400)
        case .unauthorized: throw APIError.unauthorized
        case .forbidden: throw APIError.unexpectedStatus(403)
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// Rows the server wrote after `since`, and the cursor for the next pull.
    public func pull(athleteId: UUID, since: String?) async throws -> (cursor: String?, changes: SyncChanges) {
        let sinceDate = try since.map {
            try Date($0, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        }
        switch try await client.syncPull(query: .init(athleteId: athleteId.uuidString.lowercased(), since: sinceDate)) {
        case .ok(let ok):
            let body = try ok.body.json
            return (body.cursor, try Self.convert(body.changes))
        case .badRequest: throw APIError.unexpectedStatus(400)
        case .unauthorized: throw APIError.unauthorized
        case .forbidden: throw APIError.unexpectedStatus(403)
        case .undocumented(let status, _): throw APIError.unexpectedStatus(status)
        }
    }

    /// The generated free-form containers and `SyncChanges` share the same JSON, so convert through it.
    private static func convert<From: Encodable, To: Decodable>(_ value: From) throws -> To {
        try JSONDecoder().decode(To.self, from: JSONEncoder().encode(value))
    }
}
