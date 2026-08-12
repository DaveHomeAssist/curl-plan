import Foundation
import XCTest
@testable import CurlPlanCore

@MainActor
final class AccountRuntimeTests: XCTestCase {
    func testUnconfiguredRuntimeDoesNotSendAccountRequests() async throws {
        let defaults = isolatedDefaults()
        let loader = RecordingRuntimeHTTPDataLoader()
        let runtime = AccountRuntime(baseURL: nil, defaults: defaults, loader: loader)

        let result = await runtime.createAccount(handle: "dana",
                                                 password: "runtime-pass-87",
                                                 season: AccountSeasonPayload())

        XCTAssertEqual(runtime.state.kind, .unconfigured)
        XCTAssertTrue(result.message.contains("local season data only"))
        XCTAssertEqual(loader.requests.count, 0)
    }

    func testRuntimeCreatesSignsOutAndRestoresSeasonWithoutPersistingBearerSession() async throws {
        let defaults = isolatedDefaults()
        let loader = RecordingRuntimeHTTPDataLoader()
        let runtime = AccountRuntime(baseURL: URL(string: "http://127.0.0.1:8787")!,
                                     defaults: defaults,
                                     loader: loader)
        var season = AccountSeasonPayload()
        season.profile = AccountSeasonProfile.blank(name: "Dana Mercer",
                                             homeClub: "Calgary Granite CC",
                                             province: "AB")
        let account = CurlPlanAccount(id: "acct-runtime",
                                      createdAt: "now",
                                      status: .active,
                                      deletedAt: nil)
        let sessionA = AccountSession(id: "sess-runtime-a",
                                      accountID: account.id,
                                      deviceID: "device-a",
                                      createdAt: "now",
                                      expiresAt: "later",
                                      state: .active)
        let sessionB = AccountSession(id: "sess-runtime-b",
                                      accountID: account.id,
                                      deviceID: "device-b",
                                      createdAt: "now",
                                      expiresAt: "later",
                                      state: .active)
        let document = AccountSeasonDocument(id: "season-runtime",
                                             accountID: account.id,
                                             schemaVersion: season.schemaVersion,
                                             version: 1,
                                             body: season,
                                             updatedAt: "now")

        loader.enqueue(status: 201, body: account)
        loader.enqueue(status: 200, body: sessionA)
        loader.enqueue(status: 201, body: document)
        loader.enqueue(status: 200, body: ["account", "profile", "season"])

        let create = await runtime.createAccount(handle: "dana", password: "runtime-pass-87", season: season)

        XCTAssertEqual(runtime.state.kind, .signedIn)
        XCTAssertEqual(create.message, "Backend account acct-runtime imported season version 1.")
        XCTAssertEqual(defaults.string(forKey: AccountRuntime.accountIDKey), account.id)
        XCTAssertEqual(defaults.string(forKey: AccountRuntime.handleKey), "dana")
        XCTAssertNil(defaults.string(forKey: "curlplan.account.backend.sessionID"))
        XCTAssertEqual(loader.requests.map { $0.url?.path }, [
            "/v1/accounts",
            "/v1/auth/sign-in",
            "/v1/me/season/import-local",
            "/v1/me/export"
        ])
        XCTAssertEqual(loader.requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer sess-runtime-a")

        loader.enqueue(status: 204)
        let signOut = await runtime.signOut()
        XCTAssertEqual(signOut.message, "Backend session signed out. Local season data is unchanged.")
        XCTAssertEqual(runtime.state.kind, .signedOut)

        loader.enqueue(status: 200, body: sessionB)
        loader.enqueue(status: 200, body: document)
        loader.enqueue(status: 200, body: ["account", "profile", "season"])

        let restore = await runtime.signIn(handle: "dana", password: "runtime-pass-87")

        XCTAssertEqual(runtime.state.kind, .signedIn)
        XCTAssertEqual(restore.restoredSeason?.profile.name, "Dana Mercer")
        XCTAssertEqual(loader.requests.suffix(3).map { $0.url?.path }, [
            "/v1/auth/sign-in",
            "/v1/me/season",
            "/v1/me/export"
        ])
        XCTAssertEqual(loader.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer sess-runtime-b")
    }

    private func isolatedDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
        let suiteName = "AccountRuntimeTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults", file: file, line: line)
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class RecordingRuntimeHTTPDataLoader: AccountHTTPDataLoading {
    private struct Stub {
        var status: Int
        var data: Data
    }

    private var stubs: [Stub] = []
    private(set) var requests: [URLRequest] = []
    private let encoder = JSONEncoder()

    func enqueue<Body: Encodable>(status: Int, body: Body) {
        stubs.append(Stub(status: status, data: (try? encoder.encode(body)) ?? Data()))
    }

    func enqueue(status: Int) {
        stubs.append(Stub(status: status, data: Data()))
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let stub = stubs.removeFirst()
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: stub.status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        return (stub.data, response)
    }
}
