import XCTest
@testable import CurlPlan

// Unit tests for the Store derivation + persistence + identity layer (Phase 1 core).
//
// NOTE: these live OUTSIDE ios/CurlPlan/ so generate-xcodeproj.js (which globs the app
// target) does not compile them into the app. To run them, add a Unit Testing target in
// Xcode with this file, or extend generate-xcodeproj.js to emit a test target. Each test
// isolates persistence via an ephemeral UserDefaults suite (Store.defaults seam).
final class StoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: "curlplan.tests")!
        suite.removePersistentDomain(forName: "curlplan.tests")
        Store.defaults = suite
    }

    func testFollowOverridesSeed() {
        let s = Store(); s.exploreDemo()
        XCTAssertFalse(s.isFollowing("sam"))   // seed following=false
        s.toggleFollow("sam")
        XCTAssertTrue(s.isFollowing("sam"))
    }

    func testLikePersistsAcrossReload() {
        let s = Store(); s.exploreDemo()
        s.toggleLike("seed-1")
        XCTAssertTrue(s.isLiked("seed-1"))
        XCTAssertEqual(s.likeCount(s.allPosts.first { $0.id == "seed-1" }!), 25) // 24 seed + 1
        let reloaded = Store()                 // same session + defaults
        XCTAssertTrue(reloaded.isLiked("seed-1"))
    }

    func testSpielStatusUnifiedAndPersists() {
        let s = Store(); s.exploreDemo()
        XCTAssertEqual(s.spielStatus("sp2"), "Watching")   // seed
        s.setSpielStatus("sp2", "You're in")
        XCTAssertEqual(s.spielStatus("sp2"), "You're in")
        XCTAssertTrue(Store().spielStatus("sp2") == "You're in")
    }

    func testDerivedStatsFromDemoLog() {
        let s = Store(); s.exploreDemo()
        s.addResult(body: "", scoreFor: 8, scoreAgainst: 4, vs: "Northern")  // WIN
        s.addResult(body: "", scoreFor: 3, scoreAgainst: 9, vs: "South")     // LOSS
        s.addVisit("kelowna", date: "Today", note: "")
        let st = s.derivedStats()
        XCTAssertEqual(st.games, 2)
        XCTAssertEqual(st.win, 50)
        XCTAssertEqual(st.clubs, 1)
        XCTAssertEqual(st.prov, 1)
    }

    func testStopContributionsClampAndPersist() {
        let s = Store(); s.exploreDemo()
        s.addVisit("vernon", date: "Today", note: "hi")
        s.addIceRead("vernon", speed: "Fast", curl: "5", note: "")
        s.addStopReview("vernon", stars: 9, note: "great")   // clamps to 5
        XCTAssertEqual(s.visits("vernon").count, 1)
        XCTAssertEqual(s.iceReads("vernon").count, 1)
        XCTAssertEqual(s.reviews("vernon").first?.stars, 5)
        XCTAssertEqual(Store().visits("vernon").count, 1)    // persisted
    }

    func testMessagingIgnoresBlank() {
        let s = Store(); s.exploreDemo()
        s.sendMessage("sam", text: "hello")
        s.sendMessage("sam", text: "   ")                    // blank ignored
        XCTAssertEqual(s.thread("sam").count, 1)
        XCTAssertEqual(s.thread("sam").first?.from, "me")
    }

    func testAddCurlerAndSpielAppearInDerivedCollections() {
        let s = Store(); s.exploreDemo()
        let baseCurlers = s.curlers.count
        let c = s.addCurler(name: "New Person", role: "Lead", club: "X CC", prov: "ON")
        XCTAssertEqual(s.curlers.count, baseCurlers + 1)
        XCTAssertNotNil(s.curler(c.id))
        let baseSpiels = s.spiels.count
        _ = s.addSpiel(name: "New Spiel", whereText: "", whenText: "", status: "Watching")
        XCTAssertEqual(s.spiels.count, baseSpiels + 1)
    }

    func testDemoStateSurvivesSignOutAndReturn() {
        let s = Store(); s.exploreDemo()
        s.addNote(body: "demo note")
        XCTAssertEqual(s.allPosts.filter { $0.author == "me" }.count, 1)
        s.signOut()
        XCTAssertFalse(s.isSignedIn)
        s.exploreDemo()
        XCTAssertEqual(s.allPosts.filter { $0.author == "me" }.count, 1)
    }

    func testPostCarriesTimestamp() {
        let s = Store(); s.exploreDemo()
        s.addNote(body: "hi")
        XCTAssertNotNil(s.allPosts.first?.at)
    }

    func testLegacyCredentialRecordIsPurged() {
        let legacy = #"{"users":[{"id":"legacy","name":"Ada","email":"a@x.co","passHash":"unsafe","club":"A","role":"Skip","prov":"BC"}],"session":"legacy"}"#
        Store.defaults.set(Data(legacy.utf8), forKey: "cp.auth.v1")
        let s = Store()
        XCTAssertFalse(s.isSignedIn)
        let stored = Store.defaults.data(forKey: "cp.auth.v1").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(stored.contains("passHash"))
        XCTAssertFalse(stored.contains("a@x.co"))
    }
}
