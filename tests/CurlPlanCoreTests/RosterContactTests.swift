import XCTest
@testable import CurlPlanCore

final class RosterContactTests: XCTestCase {
    func testPrivateContactAvailabilityCorrectionDeletionAndBackup() throws {
        let key = "curlplan.roster.tests", defaults = UserDefaults(suiteName: "curlplan.roster.tests")!
        defaults.removePersistentDomain(forName: key)
        let previous = Store.defaults; Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: key) }
        let store = Store(); store.exploreDemo()
        var d = RosterDetails(); d.isSpare = true; d.contact = "test@example.invalid"
        d.availability = "Available"; d.from = "2026-02-30"; d.through = "2026-03-01"
        XCTAssertFalse(store.saveRosterContact(name: "Test", role: "Second", club: "Test club", prov: "BC", details: d))
        d.from = "2026-10-01"; d.through = "2026-09-30"
        XCTAssertFalse(d.isValid)
        d.through = "2026-10-03"; d.notes = "Evenings after 6"
        XCTAssertTrue(store.saveRosterContact(name: "Test", role: "Second", club: "Test club", prov: "bc", details: d))
        let c = try XCTUnwrap(Store().state.addedCurlers.first)
        XCTAssertEqual(c.club, "Test club"); XCTAssertEqual(c.prov, "BC"); XCTAssertEqual(c.rosterDetails, d)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
        d.availability = "Unavailable"; d.notes = "Away"
        XCTAssertTrue(store.saveRosterContact(id: c.id, name: "Test updated", role: "Lead", club: "New club", prov: "AB", details: d))
        XCTAssertEqual(Store().state.addedCurlers.count, 1)
        XCTAssertEqual(Store().curler(c.id)?.rosterDetails, d)
        XCTAssertGreaterThan(Store().curler(c.id)?.at ?? 0, c.at ?? 0)
        XCTAssertFalse(store.saveRosterContact(id: "sam", name: "Changed sample", role: "Lead", club: "", prov: "", details: d))
        XCTAssertFalse(store.deleteRosterContact("sam"))
        XCTAssertTrue(store.deleteRosterContact(c.id)); XCTAssertNil(Store().curler(c.id))
        XCTAssertNotNil(Store().state.tombstones["addedCurlers"]?[c.id])
        XCTAssertFalse(store.saveRosterContact(id: c.id, name: "Stale", role: "Lead", club: "", prov: "", details: d))
        let old = store.addCurler(name: "Legacy", role: "Spare", club: "", prov: "")
        XCTAssertNil(old.rosterDetails)
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
    }
}
