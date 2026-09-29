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
        loader.enqueue(status: 200, body: ["account", "profile", "season"])
        _ = await runtime.exportAccountData()
        XCTAssertEqual(runtime.state.kind, .signedIn)
        XCTAssertEqual(runtime.state.seasonVersion, document.version, "Export must preserve the restored season version")
        var archive = AccountExportDocument(formatVersion: 1, exportedAt: "2026-09-28T00:00:00Z",
                                            account: account,
                                            profile: AccountProfile(accountID: account.id, handle: "dana", displayName: "Dana Mercer",
                                                                    homeClub: "Calgary Granite CC", avatarURL: nil,
                                                                    visibility: .privateProfile, searchable: false),
                                            season: document, ownedSharedObjects: [], relationships: [], memberships: [],
                                            interactions: [], reports: [])
        loader.enqueue(status: 200, body: archive)
        let download = await runtime.downloadAccountData()
        let file = try XCTUnwrap(download.exportData)
        XCTAssertEqual(try JSONDecoder().decode(AccountExportDocument.self, from: file), archive)
        XCTAssertEqual(loader.requests.last?.httpMethod, "GET")
        XCTAssertEqual(loader.requests.last?.url?.path, "/v1/me/export")
        XCTAssertEqual(loader.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer sess-runtime-b")
        XCTAssertFalse(String(decoding: file, as: UTF8.self).contains("sess-runtime-b"))
        archive.formatVersion = 99
        loader.enqueue(status: 200, body: archive)
        let unsupported = await runtime.downloadAccountData()
        XCTAssertNil(unsupported.exportData)
        XCTAssertTrue(unsupported.message.contains("EXPORT_FORMAT_UNSUPPORTED"))
        archive.formatVersion = 1
        archive.account.id = "other-account"
        loader.enqueue(status: 200, body: archive)
        let mismatched = await runtime.downloadAccountData()
        XCTAssertNil(mismatched.exportData)
        XCTAssertTrue(mismatched.message.contains("EXPORT_ACCOUNT_MISMATCH"))


    }

    func testAccountActionsDoNotRacePendingSignInOrSignOut() async throws {
        let loader = RecordingRuntimeHTTPDataLoader()
        let runtime = AccountRuntime(baseURL: URL(string: "http://127.0.0.1:8787")!,
                                     defaults: isolatedDefaults(), loader: loader)
        let session = AccountSession(id: "pending-session", accountID: "pending-account",
                                     deviceID: "device-a", createdAt: "now", expiresAt: "later", state: .active)
        let season = AccountSeasonPayload()
        let document = AccountSeasonDocument(id: "pending-season", accountID: session.accountID,
                                             schemaVersion: season.schemaVersion, version: 7,
                                             body: season, updatedAt: "now")
        loader.enqueue(status: 200, body: session)
        loader.enqueue(status: 200, body: document)
        loader.enqueue(status: 200, body: ["account", "profile", "season"])
        let paused = expectation(description: "Sign-in request is in flight")
        loader.pauseNext = true
        loader.onPause = { paused.fulfill() }
        let signIn = Task { await runtime.signIn(handle: "pending", password: "test-password-87") }
        await fulfillment(of: [paused], timeout: 3)
        XCTAssertTrue(runtime.isBusy)
        let rejected = [
            await runtime.signOut(),
            await runtime.signIn(handle: "other", password: "other-password-87"),
            await runtime.createAccount(handle: "other", password: "other-password-87", season: season),
            await runtime.exportAccountData(),
            await runtime.downloadAccountData(),
            await runtime.deleteAccount()
        ]
        XCTAssertTrue(runtime.isBusy, "A competing request must not replace the in-flight state")
        XCTAssertTrue(rejected.allSatisfy { $0.message.contains("already running") })
        XCTAssertEqual(loader.requests.count, 1)
        loader.resume()
        _ = await signIn.value
        XCTAssertTrue(runtime.isSignedIn)
        XCTAssertEqual(runtime.state.seasonVersion, 7)
        loader.enqueue(status: 204)
        let revoking = expectation(description: "Sign-out request is in flight")
        loader.pauseNext = true
        loader.onPause = { revoking.fulfill() }
        let signOut = Task { await runtime.signOut() }
        await fulfillment(of: [revoking], timeout: 3)
        XCTAssertTrue(runtime.isBusy)
        let duringRevocation = await runtime.signIn(handle: "other", password: "other-password-87")
        XCTAssertTrue(duringRevocation.message.contains("already running"))
        XCTAssertEqual(loader.requests.count, 4)
        loader.resume()
        _ = await signOut.value
        XCTAssertEqual(runtime.state.kind, .signedOut)
        XCTAssertEqual(loader.requests.last?.url?.path, "/v1/auth/sign-out")
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
    var pauseNext = false
    var onPause: (() -> Void)?
    private var suspended: CheckedContinuation<Void, Never>?

    func resume() { suspended?.resume(); suspended = nil }


    func enqueue<Body: Encodable>(status: Int, body: Body) {
        stubs.append(Stub(status: status, data: (try? encoder.encode(body)) ?? Data()))
    }

    func enqueue(status: Int) {
        stubs.append(Stub(status: status, data: Data()))
    }

    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if pauseNext {
            pauseNext = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                onPause?()
            }
        }

        let stub = stubs.removeFirst()
        let response = HTTPURLResponse(url: request.url!,
                                       statusCode: stub.status,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        return (stub.data, response)
    }
}
