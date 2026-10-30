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
}
