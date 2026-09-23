import XCTest

final class CurlPlanAccessibilityUITests: XCTestCase {
    func testPassportControlAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 3) { enter.tap() }

        XCTAssertTrue(app.buttons["curlplan.stop.kelowna"].waitForExistence(timeout: 10))
        try audit(app, "passport-controls", for: [.hitRegion, .sufficientElementDescription])
    }

    func testDemoScreenAccessibility() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launch()

        let enter = app.buttons["curlplan.demo.enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "Fresh launch must show the demo gate")
        try audit(app, "demo-gate")
        enter.tap()

        let passport = app.tabBars.buttons["Passport"]
        XCTAssertTrue(passport.waitForExistence(timeout: 10))
        try audit(app, "passport")

        app.buttons["curlplan.stop.kelowna"].tap()
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 5))
        try audit(app, "stop-detail")
        app.buttons["curlplan.detail.back"].tap()

        try openTab(app, "locker", title: "Locker Room")
        try openTab(app, "spiels", title: "Spiels")
        try openTab(app, "roster", title: "Roster")

        let curler = app.buttons["curlplan.curler.sam"]
        XCTAssertTrue(curler.waitForExistence(timeout: 5))
        curler.tap()
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 5))
        try audit(app, "curler-profile")
    }

    private func openTab(_ app: XCUIApplication, _ id: String, title: String) throws {
        let tab = app.tabBars.buttons[title == "Locker Room" ? "Locker" : title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "\(title) tab must be reachable")
        tab.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(title) screen must render")
        try audit(app, "tab-\(id)")
    }

    private func audit(_ app: XCUIApplication, _ name: String,
                       for types: XCUIAccessibilityAuditType = .all) throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try app.performAccessibilityAudit(for: types) { issue in
            print("ACCESSIBILITY AUDIT [\(name)]: \(issue.compactDescription); element=\(issue.element?.label ?? "none")")
            return false
        }
    }
}
