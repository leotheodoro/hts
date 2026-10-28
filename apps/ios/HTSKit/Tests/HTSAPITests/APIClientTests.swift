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
}
