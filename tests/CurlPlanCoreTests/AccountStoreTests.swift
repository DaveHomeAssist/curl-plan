import Foundation
import XCTest
@testable import CurlPlanCore

final class AccountStoreTests: XCTestCase {
    private var suite: String!
    private var previous: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "curlplan.account.store.tests.\(UUID().uuidString)"
        previous = Store.defaults
        Store.defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() {
        Store.defaults.removePersistentDomain(forName: suite)
        Store.defaults = previous
        super.tearDown()
    }

    private let profile = AccountSeasonProfile(name: "Alex Curler", homeClub: "Local Club", province: "ON")

    func testAccountSwitchAndRestartPreserveSeparateRecordsAndRequireAuthentication() throws {
        let store = Store(); store.exploreDemo()
        let stop = store.stops[0].id
        store.addVisit(stop, date: "2026-09-28", note: "Demo only")
        let demo = store.state
        try store.enterBackendAccount(accountID: "account-a", profile: profile)
        XCTAssertTrue(store.isRealAccount)
        XCTAssertEqual(store.me.name, "Alex Curler")
        XCTAssertEqual(store.me.initials, "AC")
        XCTAssertEqual(store.me.stats.clubs, 0)
        XCTAssertEqual(store.state, AppState())
        store.addVisit(stop, date: "2026-09-28", note: "Account A only")
        let a = store.state
        try store.enterBackendAccount(accountID: "account-b", profile: profile)
        XCTAssertEqual(store.state, AppState())
        store.addVisit(stop, date: "2026-09-28", note: "Account B only")
        let b = store.state
        let restarted = Store()
        XCTAssertFalse(restarted.isSignedIn, "Persisted identity is not backend authentication")
        XCTAssertNil(restarted.currentUser())
        XCTAssertEqual(restarted.state, AppState())
        try restarted.enterBackendAccount(accountID: "account-a", profile: profile)
        XCTAssertEqual(restarted.state, a)
        XCTAssertEqual(restarted.me.stats.clubs, 1)
        restarted.signOut()
        XCTAssertNil(restarted.backendIdentity)
        try restarted.enterBackendAccount(accountID: "account-b", profile: profile)
        XCTAssertEqual(restarted.state, b)
        restarted.exploreDemo()
        XCTAssertEqual(restarted.state, demo)
        XCTAssertNil(restarted.backendIdentity)
    }

    func testRestoreRequiresMatchingAccountAndKeepsRecoverableLocalCopy() throws {
        let store = Store(); store.exploreDemo()
        let demo = store.state
        var remote = AppState(); remote.messageDrafts = ["remote": "Saved remote draft"]
        let season = AccountSeasonPayload(profile: profile, state: remote)
        XCTAssertThrowsError(try store.restoreBackendSeason(season, accountID: "demo"))
        try store.enterBackendAccount(accountID: "account-a", profile: profile)
        store.addVisit(store.stops[0].id, date: "2026-09-28", note: "Local before restore")
        let before = store.state
        XCTAssertThrowsError(try store.restoreBackendSeason(season, accountID: "account-b"))
        XCTAssertEqual(store.state, before)
        XCTAssertNil(store.recoveryBackup)
        try store.restoreBackendSeason(season, accountID: "account-a")
        XCTAssertEqual(store.state, remote)
        let recovery = try XCTUnwrap(store.recoveryBackup)
        XCTAssertEqual(try store.previewBackup(recovery).state, before)
        try store.restoreBackup(recovery)
        XCTAssertEqual(store.state, before)
        store.exploreDemo()
        XCTAssertEqual(store.state, demo)
    }

    func testInvalidIdentityAndInvalidSeasonDoNotMutateRecords() throws {
        let store = Store(); store.exploreDemo()
        let before = store.state
        for id in ["", "demo", "DEMO", "anon", "account:beforeRestore", "account/other", String(repeating: "a", count: 129)] {
            XCTAssertThrowsError(try store.enterBackendAccount(accountID: id, profile: profile), id)
            XCTAssertEqual(store.currentUser()?.id, "demo")
            XCTAssertEqual(store.state, before)
        }
        try store.enterBackendAccount(accountID: "account-a", profile: profile)
        var invalid = AccountSeasonPayload(schemaVersion: 4, profile: profile)
        XCTAssertThrowsError(try store.restoreBackendSeason(invalid, accountID: "account-a"))
        invalid.schemaVersion = 3
        invalid.profile.name = "  "
        XCTAssertThrowsError(try store.restoreBackendSeason(invalid, accountID: "account-a"))
        XCTAssertNil(store.recoveryBackup)
        XCTAssertEqual(store.state, AppState())
    }

    func testRemotePayloadRejectsFieldsThatTolerantLocalDecoderWouldDrop() throws {
        let valid = AccountSeasonPayload(profile: profile)
        let data = try JSONEncoder().encode(valid)
        XCTAssertEqual(try AccountSeasonPayload.validated(data), valid)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for field in ["posts", "visits", "futureRecords"] {
            var bad = raw
            var state = try XCTUnwrap(bad["state"] as? [String: Any])
            state[field] = "unexpected records"
            bad["state"] = state
            let corrupt = try JSONSerialization.data(withJSONObject: bad)
            XCTAssertNoThrow(try JSONDecoder().decode(AccountSeasonPayload.self, from: corrupt))
            XCTAssertThrowsError(try AccountSeasonPayload.validated(corrupt), field)
        }
    }
}
