import XCTest
@testable import CurlPlanCore

final class LessonPreparationTests: XCTestCase {
    func testLessonAppendsWithoutLosingPreparationOrDraftAndIsIdempotent() throws {
        let name = "curlplan.lesson.tests", defaults = UserDefaults(suiteName: "curlplan.lesson.tests")!
        defaults.removePersistentDomain(forName: name)
        let previous = Store.defaults; Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: name) }
        let store = Store(); store.exploreDemo()
        store.addNote(body: "Finish balanced")
        let post = store.state.posts[0].id, start = Store.now() + 86400
        XCTAssertTrue(store.saveScheduledEvent(name: "Next league game", location: "Club", start: start, end: start + 7200,
            timeZone: "America/Toronto", kind: "League game", preparation: "Bring shoes", status: "Going"))
        let event = store.state.addedSpiels[0].id
        var draft = EventDraft(); draft.name = "Unsaved event name"; draft.preparation = "Meet captain"
        store.saveEventDraft(draft, editingID: event)
        XCTAssertTrue(store.useLesson(post, eventID: event))
        let prepared = Store().spiel(event)?.preparation
        XCTAssertEqual(prepared, "Bring shoes\n\nLesson for this game: Finish balanced")
        XCTAssertEqual(Store().state.eventDrafts?[event]?.preparation, "Meet captain\n\nLesson for this game: Finish balanced")
        XCTAssertEqual(Store().state.eventDrafts?[event]?.name, "Unsaved event name")
        XCTAssertTrue(store.useLesson(post, eventID: event)); XCTAssertEqual(store.spiel(event)?.preparation, prepared)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
        XCTAssertFalse(store.useLesson("missing", eventID: event))
        XCTAssertTrue(store.deletePost(post)); XCTAssertFalse(store.useLesson(post, eventID: event))
        XCTAssertEqual(Store().spiel(event)?.preparation, prepared)
    }
}
