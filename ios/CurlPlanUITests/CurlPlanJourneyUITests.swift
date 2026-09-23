import XCTest

final class CurlPlanJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testDemoTabsDetailsAndRelaunch() {
        let enter = app.buttons["curlplan.demo.enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "Fresh launch must show the demo gate")
        capture("demo-gate")
        enter.tap()

        let passport = app.buttons["curlplan.tab.passport"]
        XCTAssertTrue(passport.waitForExistence(timeout: 10), "Passport tab must be reachable")
        XCTAssertTrue(app.buttons["curlplan.stop.kelowna"].exists)
        capture("passport")

        app.buttons["curlplan.stop.kelowna"].tap()
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 5))
        capture("stop-detail")
        app.buttons["curlplan.detail.back"].tap()
        XCTAssertTrue(app.buttons["curlplan.stop.kelowna"].waitForExistence(timeout: 5))

        openTab("locker", title: "Locker Room")
        openTab("spiels", title: "Spiels")
        openTab("roster", title: "Roster")

        let curler = app.buttons["curlplan.curler.sam"]
        XCTAssertTrue(curler.waitForExistence(timeout: 5))
        curler.tap()
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 5))
        let follow = app.buttons["curlplan.profile.follow"]
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        let before = follow.label
        follow.tap()
        let after = follow.label
        XCTAssertNotEqual(before, after, "Follow state must change visibly")
        capture("curler-profile")
        app.buttons["curlplan.detail.back"].tap()
        XCTAssertTrue(app.buttons["curlplan.curler.sam"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["curlplan.tab.passport"].waitForExistence(timeout: 10), "Demo session must survive relaunch")
        openTab("roster", title: "Roster")
        app.buttons["curlplan.curler.sam"].tap()
        XCTAssertEqual(app.buttons["curlplan.profile.follow"].label, after, "Follow state must survive relaunch")
        capture("relaunch-profile")
    }

    private func openTab(_ id: String, title: String) {
        let tab = app.buttons["curlplan.tab.\(id)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(title) tab must be reachable")
        tab.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(title) screen must render")
        capture("tab-\(id)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
