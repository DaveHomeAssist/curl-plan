import XCTest
@testable import CurlPlanCore

final class EventResultTests: XCTestCase {
    func testLinkSurvivesRescheduleDeletionAndCorrectionUntilExplicitUnlink() throws {
        let name = "curlplan.result.link.tests", defaults = UserDefaults(suiteName: "curlplan.result.link.tests")!
        defaults.removePersistentDomain(forName: name)
        let previous = Store.defaults; Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: name) }
        let store = Store(); store.exploreDemo()
        XCTAssertTrue(store.saveScheduledEvent(name: "League final", location: "Club", start: 100, end: 200,
            timeZone: "America/Toronto", kind: "League game", preparation: "", status: "Going"))
        let event = store.state.addedSpiels[0].id
        var draft = PostDraft(); draft.kind = .result; draft.scoreFor = "8"; draft.scoreAgainst = "3"; draft.eventID = event
        store.savePostDraft(draft)
        XCTAssertEqual(Store().state.postDrafts["new"]?.eventID, event)
        XCTAssertTrue(store.savePost(draft))
        let post = store.state.posts[0]
        XCTAssertEqual(Store().state.posts[0].eventID, event)
        XCTAssertEqual(PostDraft(post: post).eventID, event)
        XCTAssertTrue(store.saveScheduledEvent(id: event, name: "Rescheduled final", location: "Club", start: 300, end: 400,
            timeZone: "America/Toronto", kind: "League game", preparation: "", status: "Going"))
        XCTAssertEqual(Store().state.posts[0].eventID, event)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
        XCTAssertTrue(store.deleteScheduledEvent(event))
        draft.scoreFor = "7"
        XCTAssertTrue(store.savePost(draft, editingID: post.id))
        XCTAssertEqual(Store().state.posts[0].eventName, "League final")
        XCTAssertFalse(store.savePost(draft))
        draft.eventID = nil; XCTAssertTrue(store.savePost(draft, editingID: post.id))
        XCTAssertNil(Store().state.posts[0].eventID)
        XCTAssertNil(Store().state.posts[0].eventName)
        XCTAssertEqual(store.derivedStats().games, 1)
    }
}
