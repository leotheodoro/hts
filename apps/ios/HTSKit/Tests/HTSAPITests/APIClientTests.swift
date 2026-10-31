import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import HTSAPI

/// Answers every request with a fixed status and JSON body.
struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let json: String
    var expectedAuthorization: String?

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (
        HTTPResponse, HTTPBody?
    ) {
        if let expectedAuthorization, request.headerFields[.authorization] != expectedAuthorization {
            return (HTTPResponse(status: .unauthorized), HTTPBody(#"{"error":"unauthorized"}"#))
        }
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }
}

let configuration = APIConfiguration(baseURL: URL(string: "http://localhost:8787")!)

@Suite struct APIClientTests {
    @Test func decodesHealth() async throws {
        let client = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .ok, json: #"{"status":"ok","version":"0.1.0"}"#))
        #expect(try await client.health() == HealthStatus(status: "ok", version: "0.1.0"))
    }

    @Test func returnsNilForUnknownAthlete() async throws {
        let client = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .notFound, json: #"{"error":"athlete_not_found"}"#))
        #expect(try await client.athlete(id: UUID()) == nil)
    }

    @Test func classifiesTimeoutsAndUnreachableHosts() {
        #expect(APIFailure(URLError(.timedOut)) == .timedOut)
        #expect(APIFailure(URLError(.cannotConnectToHost)) == .unreachable)
        #expect(APIFailure(APIError.invalidResponse) != .timedOut)
    }

    @Test func sendsTheBearerToken() async throws {
        let transport = StubTransport(
            status: .notFound, json: #"{"error":"athlete_not_found"}"#, expectedAuthorization: "Bearer secret")
        let authorized = APIClient(
            configuration: APIConfiguration(baseURL: configuration.baseURL, token: "secret"), transport: transport)
        #expect(try await authorized.athlete(id: UUID()) == nil)
        let anonymous = APIClient(configuration: configuration, transport: transport)
        await #expect(throws: APIError.self) { try await anonymous.athlete(id: UUID()) }
    }

    static let sessionJSON = """
        {"token":"tok-123","athleteId":"0190f2c4-0000-7000-8000-000000000001",
         "account":{"id":"0190f2c4-0000-7000-8000-000000000002","name":"Leonardo Theodoro",
                    "username":"leotheodoro","email":"leo@example.com","avatarUrl":null}}
        """

    @Test func loginReturnsTheSession() async throws {
        let client = APIClient(
            configuration: configuration, transport: StubTransport(status: .ok, json: Self.sessionJSON))
        let session = try await client.login(identifier: "leotheodoro", password: "secret")
        #expect(session.token == "tok-123")
        #expect(session.athleteId == UUID(uuidString: "0190f2c4-0000-7000-8000-000000000001"))
        #expect(
            session.account
                == Account(
                    id: UUID(uuidString: "0190f2c4-0000-7000-8000-000000000002")!, name: "Leonardo Theodoro",
                    username: "leotheodoro", email: "leo@example.com", avatarUrl: nil))
    }

    @Test func wrongCredentialsAndTooManyAttempts() async throws {
        let wrong = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .unauthorized, json: #"{"error":"invalid_credentials"}"#))
        await #expect(throws: APIError.invalidCredentials) {
            try await wrong.login(identifier: "leo", password: "nope")
        }
        let limited = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .tooManyRequests, json: #"{"error":"too_many_attempts"}"#))
        await #expect(throws: APIError.tooManyAttempts) {
            try await limited.login(identifier: "leo", password: "nope")
        }
    }

    @Test func aRefusedSessionIsUnauthorized() async throws {
        let client = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .unauthorized, json: #"{"error":"unauthorized"}"#))
        await #expect(throws: APIError.unauthorized) { try await client.pull(athleteId: UUID(), since: nil) }
        await #expect(throws: APIError.unauthorized) { try await client.push([:]) }
        await #expect(throws: APIError.unauthorized) { try await client.athlete(id: UUID()) }
    }

    @Test func logoutSendsTheBearerToken() async throws {
        let transport = StubTransport(status: .noContent, json: "", expectedAuthorization: "Bearer tok-123")
        let signedIn = APIClient(
            configuration: APIConfiguration(baseURL: configuration.baseURL, token: "tok-123"), transport: transport)
        try await signedIn.logout()
        let anonymous = APIClient(configuration: configuration, transport: transport)
        await #expect(throws: APIError.unauthorized) { try await anonymous.logout() }
    }

    static let meJSON = """
        {"athleteId":"0190f2c4-0000-7000-8000-000000000001",
         "account":{"id":"0190f2c4-0000-7000-8000-000000000002","name":"Leo Novo",
                    "username":"leo","email":"leo@example.com","avatarUrl":null}}
        """

    @Test func updatesTheAccountAndReportsTakenValues() async throws {
        let ok = APIClient(configuration: configuration, transport: StubTransport(status: .ok, json: Self.meJSON))
        let account = try await ok.updateAccount(name: "Leo Novo", username: nil, email: nil)
        #expect(account.name == "Leo Novo")
        let username = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .conflict, json: #"{"error":"username_taken"}"#))
        await #expect(throws: APIError.usernameTaken) {
            try await username.updateAccount(name: nil, username: "x", email: nil)
        }
        let email = APIClient(
            configuration: configuration, transport: StubTransport(status: .conflict, json: #"{"error":"email_taken"}"#)
        )
        await #expect(throws: APIError.emailTaken) {
            try await email.updateAccount(name: nil, username: nil, email: "x@y.z")
        }
    }

    @Test func aWrongCurrentPasswordIsInvalidCredentials() async throws {
        let wrong = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .unauthorized, json: #"{"error":"invalid_credentials"}"#))
        await #expect(throws: APIError.invalidCredentials) {
            try await wrong.changePassword(current: "a", new: "new-password")
        }
        let revoked = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .unauthorized, json: #"{"error":"unauthorized"}"#))
        await #expect(throws: APIError.unauthorized) {
            try await revoked.changePassword(current: "a", new: "new-password")
        }
        let done = APIClient(configuration: configuration, transport: StubTransport(status: .noContent, json: ""))
        try await done.changePassword(current: "a", new: "new-password")
    }

    @Test func uploadsThePhotoAndReportsStorageErrors() async throws {
        let json = Self.meJSON.replacingOccurrences(
            of: #""avatarUrl":null"#, with: #""avatarUrl":"https://b.test/a.jpg""#)
        let ok = APIClient(configuration: configuration, transport: StubTransport(status: .ok, json: json))
        #expect(try await ok.uploadAvatar(jpeg: Data([0xFF, 0xD8, 0xFF])).avatarUrl == "https://b.test/a.jpg")
        let off = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .serviceUnavailable, json: #"{"error":"storage_unavailable"}"#))
        await #expect(throws: APIError.storageUnavailable) { try await off.uploadAvatar(jpeg: Data([0xFF])) }
        let big = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .contentTooLarge, json: #"{"error":"too_large"}"#))
        await #expect(throws: APIError.photoTooLarge) { try await big.uploadAvatar(jpeg: Data([0xFF])) }
    }

    @Test func readsTheIntegrationsAndReportsGarminUnavailable() async throws {
        let json = #"""
            {"integrations":[{"provider":"garmin","connected":true,"connectedAt":"2026-11-01T12:00:00.000Z",
            "lastActivityAt":"2026-11-02T07:00:00.000Z"}]}
            """#
        let ok = APIClient(configuration: configuration, transport: StubTransport(status: .ok, json: json))
        let status = try await ok.integrations()
        #expect(status.count == 1)
        #expect(status.first?.provider == "garmin")
        #expect(status.first?.connected == true)
        #expect(status.first?.lastActivityAt == Date(timeIntervalSince1970: 1_793_602_800))
        let off = APIClient(
            configuration: configuration,
            transport: StubTransport(status: .serviceUnavailable, json: #"{"error":"garmin_unavailable"}"#))
        await #expect(throws: APIError.garminUnavailable) { _ = try await off.connectGarmin() }
        let gone = APIClient(configuration: configuration, transport: StubTransport(status: .noContent, json: ""))
        try await gone.disconnectGarmin()
    }
}
