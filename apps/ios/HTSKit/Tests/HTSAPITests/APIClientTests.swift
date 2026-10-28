import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import HTSAPI

/// Answers every request with a fixed status and JSON body.
struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let json: String

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (
        HTTPResponse, HTTPBody?
    ) {
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

}
