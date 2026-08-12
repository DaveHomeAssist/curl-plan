import Foundation
import XCTest
@testable import CurlPlanCore

final class AccountHTTPBackendTests: XCTestCase {
    func testHTTPClientSendsAccountRestoreFlowWithBearerSessionsAndJSONBodies() async throws {
        let loader = RecordingAccountHTTPDataLoader()
        let transport = AccountHTTPBackendTransport(baseURL: URL(string: "https://api.curlplan.test")!, loader: loader)
        let client = AccountHTTPBackendClient(transport: transport)
        let account = CurlPlanAccount(id: "acct-1", createdAt: "now", status: .active, deletedAt: nil)
        let sessionA = AccountSession(id: "sess-a",
                                      accountID: account.id,
                                      deviceID: "device-a",
                                      createdAt: "now",
                                      expiresAt: "later",
                                      state: .active)
        let sessionB = AccountSession(id: "sess-b",
                                      accountID: account.id,
                                      deviceID: "device-b",
                                      createdAt: "now",
                                      expiresAt: "later",
                                      state: .active)
        var season = AccountSeasonPayload()
        season.profile = AccountSeasonProfile.blank(name: "Dana Mercer", homeClub: "Calgary Granite CC", province: "AB")
        let document = AccountSeasonDocument(id: "season-1",
                                             accountID: account.id,
                                             schemaVersion: season.schemaVersion,
                                             version: 1,
                                             body: season,
                                             updatedAt: "now")

        loader.enqueue(status: 201, body: account)
        loader.enqueue(status: 200, body: sessionA)
        loader.enqueue(status: 201, body: document)
        loader.enqueue(status: 204)
        loader.enqueue(status: 200, body: sessionB)
        loader.enqueue(status: 200, body: document)
        loader.enqueue(status: 204)

        let created = try await client.createAccount(handle: "dana",
                                                     displayName: "Dana Mercer",
                                                     homeClub: "Calgary Granite CC",
                                                     password: "http-pass-87")
        XCTAssertEqual(created.id, "acct-1")
        try await client.signIn(handle: "dana", password: "http-pass-87", deviceID: "device-a")
        try await client.importLocalSeason(season)
        try await client.signOut()
        try await client.signIn(handle: "dana", password: "http-pass-87", deviceID: "device-b")
        let restored = try await client.season()
        XCTAssertEqual(restored.body.profile.name, "Dana Mercer")
        try await client.deleteAccount()

        XCTAssertEqual(loader.requests.map { $0.httpMethod }, ["POST", "POST", "POST", "POST", "POST", "GET", "DELETE"])
        XCTAssertEqual(loader.requests.map { $0.url?.path }, [
            "/v1/accounts",
            "/v1/auth/sign-in",
            "/v1/me/season/import-local",
            "/v1/auth/sign-out",
            "/v1/auth/sign-in",
            "/v1/me/season",
            "/v1/me"
        ])

        let createBody = try XCTUnwrap(loader.requests[0].httpBody)
        XCTAssertEqual(try JSONDecoder().decode(AccountCreateRequest.self, from: createBody),
                       AccountCreateRequest(handle: "dana",
                                            displayName: "Dana Mercer",
                                            homeClub: "Calgary Granite CC",
                                            password: "http-pass-87"))

        let signInBody = try XCTUnwrap(loader.requests[1].httpBody)
        XCTAssertEqual(try JSONDecoder().decode(AccountSignInRequest.self, from: signInBody),
                       AccountSignInRequest(handle: "dana", password: "http-pass-87", deviceID: "device-a"))
        XCTAssertNil(loader.requests[1].value(forHTTPHeaderField: "Authorization"))

        XCTAssertEqual(loader.requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer sess-a")
        let importBody = try XCTUnwrap(loader.requests[2].httpBody)
        XCTAssertEqual(try JSONDecoder().decode(AccountImportSeasonRequest.self, from: importBody).season.profile.name,
                       "Dana Mercer")

        XCTAssertEqual(loader.requests[3].value(forHTTPHeaderField: "Authorization"), "Bearer sess-a")
        XCTAssertEqual(loader.requests[5].value(forHTTPHeaderField: "Authorization"), "Bearer sess-b")
        XCTAssertEqual(loader.requests[6].value(forHTTPHeaderField: "Authorization"), "Bearer sess-b")
    }

    func testHTTPTransportMapsQueryPathsErrorEnvelopeAndNetworkFailure() async throws {
        let loader = RecordingAccountHTTPDataLoader()
        let transport = AccountHTTPBackendTransport(baseURL: URL(string: "https://api.curlplan.test/root")!, loader: loader)
        var season = AccountSeasonPayload()
        season.profile = AccountSeasonProfile.blank(name: "Dana Mercer", homeClub: "Granite Curling Club", province: "AB")

        loader.enqueue(status: 409,
                       error: AccountAPIError(status: 409,
                                              code: "VERSION_CONFLICT",
                                              message: "Current version is 2.",
                                              requestID: "req-1"))
        let conflict = await transport.applySeasonChange(sessionID: "sess-a",
                                                         baseVersion: 1,
                                                         updatedBody: season,
                                                         domains: [.profile],
                                                         clientMutationID: "client-stale")
        XCTAssertEqual(conflict.status, 409)
        XCTAssertEqual(conflict.error?.code, "VERSION_CONFLICT")
        XCTAssertEqual(loader.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sess-a")

        loader.enqueue(status: 200, body: [AccountProfile(accountID: "acct-2",
                                                         handle: "sam",
                                                         displayName: "Sam Reid",
                                                         homeClub: "Vernon CC",
                                                         avatarURL: nil,
                                                         visibility: .publicProfile,
                                                         searchable: true)])
        let profiles = await transport.searchProfiles(sessionID: "sess-a", query: "sam reid")
        XCTAssertEqual(profiles.body?.map(\.handle), ["sam"])
        XCTAssertEqual(loader.requests.last?.url?.path, "/root/v1/profiles/search")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(loader.requests.last?.url), resolvingAgainstBaseURL: false)?
            .queryItems,
            [URLQueryItem(name: "q", value: "sam reid")])

        loader.enqueue(error: URLError(.notConnectedToInternet))
        let unavailable = await transport.season(sessionID: "sess-a")
        XCTAssertEqual(unavailable.status, 503)
        XCTAssertEqual(unavailable.error?.code, "NETWORK_UNAVAILABLE")
    }

    func testHTTPClientRequiresSessionBeforeProtectedCallsWithoutSendingRequest() async throws {
        let loader = RecordingAccountHTTPDataLoader()
        let transport = AccountHTTPBackendTransport(baseURL: URL(string: "https://api.curlplan.test")!, loader: loader)
        let client = AccountHTTPBackendClient(transport: transport)

        do {
            _ = try await client.season()
            XCTFail("Expected signed out client to throw")
        } catch let error as AccountAPIError {
            XCTAssertEqual(error.status, 401)
            XCTAssertEqual(error.code, "CLIENT_SIGNED_OUT")
        }

        XCTAssertEqual(loader.requests.count, 0)
    }
}

private final class RecordingAccountHTTPDataLoader: AccountHTTPDataLoading {
    private struct Stub {
        var status: Int
        var data: Data
        var error: Error?
    }

    private var stubs: [Stub] = []
    private(set) var requests: [URLRequest] = []
    private let encoder = JSONEncoder()

    func enqueue<Body: Encodable>(status: Int, body: Body) {
        stubs.append(Stub(status: status, data: (try? encoder.encode(body)) ?? Data(), error: nil))
    }

    func enqueue(status: Int) {
        stubs.append(Stub(status: status, data: Data(), error: nil))
    }

    func enqueue(status: Int, error: AccountAPIError) {
        let envelope = AccountHTTPErrorEnvelope(error: error)
        stubs.append(Stub(status: status, data: (try? encoder.encode(envelope)) ?? Data(), error: nil))
    }

    func enqueue(error: Error) {
        stubs.append(Stub(status: 503, data: Data(), error: error))
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let stub = stubs.removeFirst()
        if let error = stub.error {
            throw error
        }
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: stub.status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        return (stub.data, response)
    }
}
