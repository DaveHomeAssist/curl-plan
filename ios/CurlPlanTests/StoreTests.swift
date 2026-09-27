import XCTest
@testable import CurlPlan

// Unit tests for the Store derivation + persistence + identity layer (Phase 1 core).
//
// NOTE: these live OUTSIDE ios/CurlPlan/ so generate-xcodeproj.js (which globs the app
// target) does not compile them into the app. The generator emits a CurlPlanTests
// unit-test target for this directory, and CI runs it via `xcodebuild test` on an
// iOS Simulator (see .github/workflows/verify.yml). Each test isolates persistence
// via an ephemeral UserDefaults suite (Store.defaults seam).
final class StoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: "curlplan.tests")!
        suite.removePersistentDomain(forName: "curlplan.tests")
        Store.defaults = suite
    }

    func testReviewCorrectionDraftAndDeletionPersist() throws {
        let s = Store(); s.exploreDemo()
        XCTAssertTrue(s.saveReview("kelowna", draft: ReviewDraft(stars: 5, note: "original")))
        let review = s.reviews("kelowna")[0]
        let draft = ReviewDraft(stars: 2, note: "corrected")
        s.saveReviewDraft("kelowna", draft: draft, editingID: review.id)
        XCTAssertEqual(Store().reviews("kelowna")[0].note, "original")
        XCTAssertEqual(Store().state.reviewDrafts[s.reviewDraftKey("kelowna", editingID: review.id)], draft)
        XCTAssertFalse(s.saveReview("unknown", draft: draft))
        XCTAssertFalse(s.saveReview("kelowna", draft: ReviewDraft(stars: 6)))
        XCTAssertTrue(s.saveReview("kelowna", draft: draft, editingID: review.id))
        let restored = Store()
        XCTAssertEqual(restored.reviews("kelowna").count, 1)
        XCTAssertEqual(restored.reviews("kelowna")[0].id, review.id)
        XCTAssertEqual(restored.reviews("kelowna")[0].stars, 2)
        XCTAssertEqual(restored.reviews("kelowna")[0].note, "corrected")
        XCTAssertTrue(restored.state.reviewDrafts.isEmpty)
        XCTAssertFalse(s.deleteReview("unknown", id: review.id))
        let stale = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(s.state))
        XCTAssertTrue(s.deleteReview("kelowna", id: review.id))
        XCTAssertTrue(Store().reviews("kelowna").isEmpty)
        XCTAssertNotNil(Store().state.tombstones["reviews"]?[review.id.uuidString])
        let deleted = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(Store().state))
        XCTAssertEqual(Merge.state(stale, deleted)["reviews"]?["kelowna"]?.asArray?.count, 0)
        XCTAssertFalse(s.saveReview("kelowna", draft: draft, editingID: review.id))
    }

    func testFollowOverridesSeed() {
        let s = Store(); s.exploreDemo()
        XCTAssertFalse(s.isFollowing("sam"))   // seed following=false
        s.toggleFollow("sam")
        XCTAssertTrue(s.isFollowing("sam"))
    }

    func testOwnedPostEditPreservesIdentityAndPersists() {
        let s = Store(); s.exploreDemo()
        s.addNote(body: "typo")
        let original = s.state.posts[0]
        s.toggleLike(original.id)
        var draft = PostDraft(post: original)
        draft.body = "corrected"
        s.savePostDraft(draft, editingID: original.id)
        XCTAssertEqual(Store().state.postDrafts[original.id]?.body, "corrected")
        XCTAssertEqual(Store().state.posts[0].body, "typo", "Draft edits must not publish")
        XCTAssertTrue(s.savePost(draft, editingID: original.id))
        let restored = Store()
        XCTAssertEqual(restored.state.posts.count, 1)
        XCTAssertEqual(restored.state.posts[0].id, original.id)
        XCTAssertEqual(restored.state.posts[0].body, "corrected")
        XCTAssertTrue(restored.isLiked(original.id))
        XCTAssertNil(restored.state.postDrafts[original.id])
    }

    func testResultCorrectionAndDeletionRecomputeStats() {
        let s = Store(); s.exploreDemo()
        s.addResult(body: "result", scoreFor: 8, scoreAgainst: 5, vs: "North")
        let id = s.state.posts[0].id
        var draft = PostDraft(post: s.state.posts[0])
        draft.scoreFor = " 2 "; draft.scoreAgainst = "5"
        XCTAssertTrue(s.savePost(draft, editingID: id))
        XCTAssertEqual(Store().state.posts[0].res, "LOSS")
        XCTAssertEqual(Store().derivedStats().win, 0)
        XCTAssertEqual(Store().state.posts[0].vs, "vs North")
        s.savePostDraft(draft, editingID: id)
        XCTAssertTrue(s.deletePost(id))
        let restored = Store()
        XCTAssertEqual(restored.derivedStats().games, 0)
        XCTAssertFalse(restored.allPosts.contains { $0.id == id })
        XCTAssertNotNil(restored.state.tombstones["posts"]?[id])
        XCTAssertNil(restored.state.postDrafts[id])
        XCTAssertFalse(s.savePost(draft, editingID: id), "Stale editor must not recreate a deleted post")
    }

    func testPostValidationAndSeedOwnership() {
        let s = Store(); s.exploreDemo()
        var draft = PostDraft(); draft.kind = .result
        draft.scoreFor = "-1"; draft.scoreAgainst = "5"
        XCTAssertFalse(s.savePost(draft))
        draft.scoreFor = "4.5"
        XCTAssertFalse(s.savePost(draft))
        draft.kind = .note; draft.body = "  \n "
        XCTAssertFalse(s.savePost(draft))
        draft.body = "valid"
        for post in Seed.feed {
            XCTAssertFalse(s.deletePost(post.id))
            XCTAssertFalse(s.savePost(draft, editingID: post.id))
        }
        XCTAssertTrue(s.state.posts.isEmpty)
        XCTAssertTrue(s.state.tombstones.isEmpty)
    }

    func testDraftRecoveryIsolationAndExplicitDiscard() {
        let s = Store(); s.exploreDemo()
        var draft = PostDraft(); draft.body = "recover after dismissal"
        draft.opponent = "North"; draft.scoreFor = "8"; draft.scoreAgainst = "5"
        s.savePostDraft(draft)
        XCTAssertEqual(Store().state.postDrafts["new"], draft)
        s.signOut()
        XCTAssertNil(Store().state.postDrafts["new"])
        s.exploreDemo()
        XCTAssertEqual(s.state.postDrafts["new"], draft)
        s.discardPostDraft()
        XCTAssertNil(Store().state.postDrafts["new"])
        s.savePostDraft(draft)
        XCTAssertTrue(s.savePost(draft))
        XCTAssertNil(Store().state.postDrafts["new"])
        XCTAssertEqual(Store().state.posts.count, 1)
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

    func testDemoLoggedStopsExcludeSampleLocationPin() {
        let s = Store(); s.exploreDemo()
        XCTAssertEqual(s.demoLoggedStops.count, 4)
        XCTAssertTrue(s.demoLoggedStops.allSatisfy { !$0.here })
        XCTAssertEqual(s.stops.filter(\.here).count, 1)
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
