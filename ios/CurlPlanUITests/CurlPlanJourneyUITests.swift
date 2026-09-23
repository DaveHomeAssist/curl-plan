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
        XCTAssertFalse(app.staticTexts["Locker Room"].exists, "Inactive tab content must not be exposed")
        capture("passport")

        tapAfterScrolling(app.buttons["curlplan.stop.kelowna"], name: "Kelowna stop")
        XCTAssertTrue(app.buttons["curlplan.detail.back"].waitForExistence(timeout: 5))
        scrollUntilHittable(app.staticTexts["ICE READ"], name: "Ice read")
        capture("stop-detail")
        openTab("locker", title: "Locker Room")
        app.buttons["curlplan.tab.passport"].tap()
        XCTAssertTrue(app.buttons["curlplan.detail.back"].waitForExistence(timeout: 5),
                      "Stop detail must survive switching tabs")
        app.buttons["curlplan.detail.back"].tap()
        XCTAssertTrue(app.buttons["curlplan.stop.kelowna"].waitForExistence(timeout: 5))

        openTab("spiels", title: "Spiels")
        openTab("roster", title: "Roster")

        let curler = app.buttons["curlplan.curler.sam"]
        XCTAssertTrue(curler.waitForExistence(timeout: 5))
        tapAfterScrolling(curler, name: "Sam Reid profile")
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 5))
        let follow = app.buttons["curlplan.profile.follow"]
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        let before = follow.label
        tapAfterScrolling(follow, name: "Follow action")
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
        tapAfterScrolling(app.buttons["curlplan.curler.sam"], name: "Sam Reid profile after relaunch")
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

    private func tapAfterScrolling(_ element: XCUIElement, name: String) {
        scrollUntilHittable(element, name: name)
        element.tap()
    }

    private func scrollUntilHittable(_ element: XCUIElement, name: String) {
        for _ in 0..<6 {
            if element.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(name) must remain reachable by scrolling")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
