import XCTest
import SwiftUI
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

    func testThemeTextPairsMeetContrast() {
        let settings = AppSettings()
        let oldTheme = settings.theme, oldAccent = settings.accentKey
        defer { settings.theme = oldTheme; settings.accentKey = oldAccent }
        func luminance(_ color: Color) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a))
            func linear(_ c: CGFloat) -> Double { let v = Double(c); return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        func ratio(_ a: Color, _ b: Color) -> Double {
            let x = luminance(a), y = luminance(b)
            return (max(x,y) + 0.05) / (min(x,y) + 0.05)
        }
        for theme in [AppSettings.AppTheme.ice, .arena] {
            settings.theme = theme
            for accent in AppSettings.accents {
                settings.accentKey = accent.key
                XCTAssertGreaterThanOrEqual(ratio(settings.onAccent, settings.accent), 4.5, "\(theme) \(accent.key) filled control")
                for surface in [settings.screen, settings.card, settings.panel] {
                    XCTAssertGreaterThanOrEqual(ratio(settings.accent, surface), 4.5)
                    XCTAssertGreaterThanOrEqual(ratio(settings.ink, surface), 4.5)
                    XCTAssertGreaterThanOrEqual(ratio(settings.muted, surface), 4.5)
                }
            }
        }
    }

    func testDatedEventOrderingConflictsRescheduleAndDeletion() throws {
        let s = Store(); s.exploreDemo()
        func save(_ id: String? = nil, _ name: String, _ start: Double, _ end: Double) -> Bool {
            s.saveScheduledEvent(id: id, name: name, location: "Club sheet 2", start: start, end: end,
                                 timeZone: "America/Toronto", kind: "League game", preparation: "Arrive early", status: "Going")
        }
        XCTAssertFalse(save(nil, "", 100, 200))
        XCTAssertFalse(save(nil, "invalid", 200, 100))
        XCTAssertTrue(save(nil, "First", 100, 200))
        let id = s.state.addedSpiels[0].id
        XCTAssertTrue(save(nil, "Adjacent", 200, 300))
        XCTAssertEqual(s.eventConflicts(start: 200, end: 300, excluding: s.state.addedSpiels[0].id).count, 0)
        XCTAssertEqual(s.eventConflicts(start: 150, end: 210).count, 2)
        XCTAssertEqual(s.upcomingEvents(now: 50).first?.id, id)
        XCTAssertTrue(save(id, "Rescheduled", 400, 500))
        XCTAssertEqual(Store().spiel(id)?.startAt, 400)
        XCTAssertEqual(Store().spiel(id)?.preparation, "Arrive early")
        XCTAssertEqual(s.upcomingEvents(now: 250).last?.id, id)
        XCTAssertEqual(try s.previewBackup(s.backupData()).state, s.state)
        var invalid = s.state
        invalid.addedSpiels[0].endAt = 0
        XCTAssertThrowsError(try LocalBackup.validate(JSONEncoder().encode(LocalBackup(account: "demo", state: invalid)), account: "demo"))
        let stale = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(s.state))
        XCTAssertTrue(s.deleteScheduledEvent(id))
        XCTAssertNil(Store().spiel(id))
        let deleted = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(s.state))
        XCTAssertEqual(Merge.state(stale, deleted)["addedSpiels"]?.asArray?.count, 1)
        XCTAssertFalse(save(id, "Stale", 600, 700))
        XCTAssertFalse(s.deleteScheduledEvent(Seed.spiels[0].id))
    }

    func testBackupPreviewRestoreRecoveryAndRejection() throws {
        let s = Store(); s.exploreDemo()
        s.addNote(body: "before export")
        s.addIceRead("kelowna", speed: "Fast", curl: "4", note: "saved", date: "2026-09-27", sheet: "A")
        var draft = PostDraft(); draft.body = "private draft"
        s.savePostDraft(draft)
        let data = try s.backupData()
        s.addNote(body: "after export")
        let current = s.state
        let preview = try s.previewBackup(data)
        XCTAssertEqual(preview.state.posts.count, 1)
        XCTAssertEqual(s.state, current, "Preview must not mutate records")
        try s.restoreBackup(data)
        XCTAssertEqual(Store().state, preview.state)
        XCTAssertEqual(Store().state.postDrafts["new"]?.body, "private draft")
        let recovery = try XCTUnwrap(s.recoveryBackup)
        try s.restoreBackup(recovery)
        XCTAssertEqual(Store().state, current, "Recovery returns all records and drafts")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["version"] = 99
        XCTAssertThrowsError(try s.restoreBackup(JSONSerialization.data(withJSONObject: object)))
        object["version"] = 1; object["account"] = "someone-else"
        XCTAssertThrowsError(try s.restoreBackup(JSONSerialization.data(withJSONObject: object)))
        object["account"] = "demo"
        var state = try XCTUnwrap(object["state"] as? [String: Any])
        state["posts"] = "corrupt"; object["state"] = state
        XCTAssertThrowsError(try s.restoreBackup(JSONSerialization.data(withJSONObject: object)))
        XCTAssertEqual(Store().state, current)
        XCTAssertThrowsError(try s.previewBackup(Data("{}".utf8)))
        XCTAssertThrowsError(try s.previewBackup(Data(repeating: 32, count: 5_000_001)))
        s.signOut()
        XCTAssertThrowsError(try s.previewBackup(data))
        XCTAssertNil(s.recoveryBackup)
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

    func testDetailLinksAndNavigationRecovery() {
        let s = Store(); s.exploreDemo()
        let router = Router(defaults: Store.defaults)
        router.restore(accountID: "demo", store: s)
        router.receive(Route.stop("kelowna").url, store: s)
        XCTAssertEqual(router.tab, .passport)
        XCTAssertEqual(router.paths[.passport], [.stop("kelowna")])
        router.tab = .roster
        router.paths[.roster] = [.curler("sam")]
        let restored = Router(defaults: Store.defaults)
        restored.restore(accountID: "demo", store: s)
        XCTAssertEqual(restored.tab, .roster)
        XCTAssertEqual(restored.paths[.roster], [.curler("sam")])
        restored.receive(URL(string: "curlplan://stop/missing")!, store: s)
        XCTAssertTrue(restored.invalidLink)
        XCTAssertEqual(restored.paths[.roster], [.curler("sam")])
        XCTAssertNil(Route(url: URL(string: "https://stop/kelowna")!))
        XCTAssertNil(Route(url: URL(string: "curlplan://stop/kelowna/extra")!))
        XCTAssertNil(Route(url: URL(string: "curlplan://stop/kelowna?other=1")!))
        restored.restore(accountID: nil, store: s)
        XCTAssertNil(Store.defaults.data(forKey: "cp.navigation.v1:demo"), "Explicit sign-out clears navigation only")
        XCTAssertTrue(restored.paths.isEmpty)
        restored.receive(Route.stop("kelowna").url, store: s)
        restored.restore(accountID: "demo", store: s)
        XCTAssertEqual(restored.tab, .passport)
        XCTAssertEqual(restored.paths[.passport], [.stop("kelowna")])
    }

    func testMessageDraftRecoveryAndSend() {
        let s = Store(); s.exploreDemo()
        s.saveMessageDraft("sam", text: "unsent")
        XCTAssertEqual(Store().state.messageDrafts["sam"], "unsent")
        XCTAssertTrue(Store().thread("sam").isEmpty)
        s.signOut(); XCTAssertTrue(s.state.messageDrafts.isEmpty)
        s.exploreDemo(); XCTAssertEqual(s.state.messageDrafts["sam"], "unsent")
        s.sendMessage("sam", text: "ready")
        XCTAssertNil(Store().state.messageDrafts["sam"])
        XCTAssertEqual(Store().thread("sam").last?.text, "ready")
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

    func testSampleClubRecordsMatchListedGames() {
        let s = Store(); s.exploreDemo()
        XCTAssertEqual(s.derivedStats().games, 0, "Samples are not personal results")
        for stop in s.stops where !stop.games.isEmpty {
            let wins = stop.games.filter { $0.res == "W" }.count
            let losses = stop.games.filter { $0.res == "L" }.count
            XCTAssertEqual(stop.record, "\(wins)–\(losses)", stop.id)
            XCTAssertEqual(stop.iceRec, stop.record, stop.id)
        }
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

    func testIceContextPersistsAndLegacyRecordsSurvive() throws {
        let legacy = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"speed\":\"Fast\",\"curl\":\"5\",\"note\":\"legacy\",\"at\":1}".utf8)
        let old = try JSONDecoder().decode(IceReadEntry.self, from: legacy)
        XCTAssertNil(old.date); XCTAssertNil(old.sheet)
        let initial = Store(); initial.exploreDemo()
        var savedState = initial.state
        savedState.iceReads["kelowna"] = [old]
        Store.defaults.set(try JSONEncoder().encode(savedState), forKey: "cp.state.v2:demo")
        let s = Store()
        s.addIceRead("kelowna", speed: "Slow", curl: "3–4", note: "late draw", date: "2026-09-27", sheet: " A ")
        let reads = Store().iceReads("kelowna")
        XCTAssertEqual(reads.count, 2)
        XCTAssertEqual(reads[0].date, "2026-09-27")
        XCTAssertEqual(reads[0].sheet, "A")
        XCTAssertEqual(reads[1].note, "legacy")
        XCTAssertNil(reads[1].date)
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
