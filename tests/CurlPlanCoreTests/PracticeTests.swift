import XCTest
@testable import CurlPlanCore

final class PracticeTests: XCTestCase {
    func testPracticeDraftCorrectionDeletionAndStatistics() throws {
        let name = "curlplan.practice.tests", defaults = UserDefaults(suiteName: "curlplan.practice.tests")!
        defaults.removePersistentDomain(forName: name)
        let previous = Store.defaults; Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: name) }
        let store = Store(); store.exploreDemo()
        var draft = PostDraft(); draft.kind = .practice
        XCTAssertFalse(store.savePost(draft))
        var practice = PracticeLog(); practice.date = "2026-02-30"; practice.minutes = "60"
        practice.drills = "Draw to button"; practice.focus = "Release"; practice.observations = "Finish balanced"
        draft.practice = practice; XCTAssertFalse(store.savePost(draft))
        practice.date = "2026-09-27"; practice.minutes = "0"; draft.practice = practice
        XCTAssertFalse(store.savePost(draft))
        practice.minutes = "60"; draft.practice = practice
        store.savePostDraft(draft)
        XCTAssertEqual(Store().state.postDrafts["new"]?.practice, practice)
        XCTAssertTrue(store.savePost(draft))
        let post = Store().state.posts[0]
        XCTAssertEqual(post.kind, .practice); XCTAssertEqual(post.practice, practice)
        XCTAssertEqual(store.derivedStats().games, 0)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
        var edit = PostDraft(post: post); edit.practice?.observations = "Keep wrist quiet"
        XCTAssertTrue(store.savePost(edit, editingID: post.id))
        XCTAssertTrue(Store().state.posts[0].body?.contains("Keep wrist quiet") == true)
        XCTAssertEqual(Store().state.posts[0].id, post.id)
        XCTAssertTrue(store.deletePost(post.id)); XCTAssertTrue(Store().state.posts.isEmpty)
    }
}
