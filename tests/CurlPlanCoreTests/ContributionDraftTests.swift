import XCTest
@testable import CurlPlanCore

final class ContributionDraftTests: XCTestCase {
    func testRecoveryIsolationSaveCleanupAndBackupCompatibility() throws {
        let suiteName = "curlplan.contribution.tests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let previous = Store.defaults
        Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: suiteName) }
        let store = Store(); store.exploreDemo()
        let oldBackup = try store.backupData()
        let stop = store.stops[0].id, other = store.stops[1].id
        var draft = ContributionDraft(); draft.note = "Preserve my reading"
        draft.curl = "4–5"; draft.speed = "Fast"; draft.sheet = "3"
        store.saveContributionDraft(stop, kind: "ice", draft: draft)
        store.saveContributionDraft(stop, kind: "visit", draft: draft)
        store.saveContributionDraft(other, kind: "ice", draft: draft)
        XCTAssertEqual(Store().state.contributionDrafts?.count, 3)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
        XCTAssertNil(try store.previewBackup(oldBackup).state.contributionDrafts)
        store.signOut(); XCTAssertNil(store.state.contributionDrafts)
        store.saveContributionDraft(stop, kind: "ice", draft: draft)
        XCTAssertNil(store.state.contributionDrafts)
        store.exploreDemo()
        XCTAssertEqual(store.state.contributionDrafts?[store.contributionDraftKey(stop, kind: "ice")], draft)
        store.addIceRead(stop, speed: draft.speed, curl: draft.curl, note: draft.note, date: "2026-09-27", sheet: draft.sheet)
        XCTAssertEqual(Store().state.contributionDrafts?.count, 2)
        XCTAssertEqual(Store().iceReads(stop).first?.sheet, "3")
        store.discardContributionDraft(other, kind: "ice")
        XCTAssertEqual(Store().iceReads(stop).count, 1)
        store.addVisit(stop, date: draft.visitDate, note: draft.note)
        XCTAssertNil(Store().state.contributionDrafts)
        XCTAssertEqual(Store().visits(stop).first?.note, draft.note)
    }
}
