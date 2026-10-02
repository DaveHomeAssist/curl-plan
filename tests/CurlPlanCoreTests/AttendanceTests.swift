import XCTest
@testable import CurlPlanCore

final class AttendanceTests: XCTestCase {
    func testIntentCompatibilityPersistenceAndWithdrawal() throws {
        let name = "curlplan.attendance.tests", defaults = UserDefaults(suiteName: "curlplan.attendance.tests")!
        defaults.removePersistentDomain(forName: name)
        let previous = Store.defaults; Store.defaults = defaults
        defer { Store.defaults = previous; defaults.removePersistentDomain(forName: name) }
        var store = Store(); store.exploreDemo()
        XCTAssertEqual(store.spielStatus("sp1"), "Considering", "Sample registration is not personal intent")
        var legacy = store.state
        legacy.joins["sp1"] = "You're in"
        legacy.joins["sp2"] = "Watching"
        defaults.set(try JSONEncoder().encode(legacy), forKey: "cp.state.v2:demo")
        store = Store()
        XCTAssertEqual(Store().spielStatus("sp1"), "Going", "Preserve explicit legacy choices")
        XCTAssertEqual(Store().spielStatus("sp2"), "Considering")
        store.setSpielStatus("sp1", "Going")
        store.withdrawSpiel("sp1")
        XCTAssertEqual(Store().spielStatus("sp1"), "Not going")
        store.setSpielStatus("sp1", "Considering")
        XCTAssertEqual(Store().spielStatus("sp1"), "Considering")
        store.setSpielStatus("sp1", "Registered")
        XCTAssertEqual(store.spielStatus("sp1"), "Considering")
        store.setSpielStatus("missing", "Going")
        XCTAssertNil(store.state.joins["missing"])
        XCTAssertEqual(try store.previewBackup(store.backupData()).state, store.state)
    }
}
