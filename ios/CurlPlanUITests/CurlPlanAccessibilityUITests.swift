import XCTest

final class CurlPlanAccessibilityUITests: XCTestCase {
    func testContributionAndSettingsLabels() throws {
        let app = XCUIApplication()
        app.launch()
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(app.buttons["Passport"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Passport"].firstMatch.tap()
        app.buttons["Open settings"].tap()
        for accent in ["House red", "House blue", "Granite"] {
            let control = app.buttons["Accent: \(accent)"]
            XCTAssertTrue(control.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
        }
        XCTAssertTrue(app.switches["Pebble texture"].exists)
        let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settings.name = "A32-settings-labels"
        settings.lifetime = .keepAlways
        add(settings)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Locker"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Locker"].firstMatch.tap()
        app.buttons["curlplan.compose.open"].tap()
        XCTAssertTrue(app.textFields["What's the word?"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        app.buttons["Passport"].firstMatch.tap()
        app.buttons["curlplan.stop.kelowna"].tap()
        app.buttons["Log visit"].tap()
        XCTAssertTrue(app.textFields["Date"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Note (optional)"].exists)
        app.buttons["Cancel"].tap()
    }

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
