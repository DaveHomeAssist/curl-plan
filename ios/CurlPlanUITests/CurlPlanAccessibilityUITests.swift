import XCTest

final class CurlPlanAccessibilityUITests: XCTestCase {
    func testActualComponentContrastControl() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        for scroll in [false, true] {
            app.launchArguments = ["--contrast-components"] + (scroll ? ["--control-scroll"] : [])
            app.launch()
            XCTAssertTrue(app.staticTexts["Component contrast control"].waitForExistence(timeout: 8))
            XCTAssertGreaterThanOrEqual(app.buttons["Ice read"].frame.height, 44)
            XCTAssertGreaterThanOrEqual(app.buttons["Log visit"].frame.height, 44)
            try audit(app, scroll ? "components-scroll" : "components-static", for: .contrast)
            app.terminate()
        }
        app.launchArguments = []; app.launch()
    }

    func testPhysicalContributionButtonTargets() throws {
        let app = XCUIApplication(); app.launch()
        app.open(URL(string: "curlplan://stop/kelowna")!)
        XCTAssertTrue(app.buttons["Log visit"].waitForExistence(timeout: 8))
        for title in ["Log visit", "Ice read", "Write review"] {
            XCTAssertGreaterThanOrEqual(app.buttons[title].frame.height, 44)
            XCTAssertTrue(app.buttons[title].isHittable)
        }
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A32-contribution-targets"; proof.lifetime = .keepAlways; add(proof)
    }

    func testContrastControl() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--contrast-control"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Black text on white"].waitForExistence(timeout: 8))
        try audit(app, "contrast-control", for: .contrast)
    }

    func testPhysicalContrastBothThemes() throws {
        continueAfterFailure = true
        let app = XCUIApplication(); app.launch()
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        for theme in ["Ice", "Arena"] {
            app.open(URL(string: "curlplan://stop/kelowna")!)
            XCTAssertTrue(app.buttons["curlplan.detail.back"].waitForExistence(timeout: 8))
            app.buttons["curlplan.detail.back"].tap()
            app.buttons["Open settings"].tap(); app.buttons[theme].tap(); app.buttons["Close settings"].tap()
            try audit(app, "physical-\(theme)-passport", for: .contrast)
            app.open(URL(string: "curlplan://stop/kelowna")!)
            XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 8))
            try audit(app, "physical-\(theme)-stop", for: .contrast)
            app.open(URL(string: "curlplan://curler/sam")!)
            XCTAssertTrue(app.buttons["Message"].waitForExistence(timeout: 8))
            try audit(app, "physical-\(theme)-profile", for: .contrast)
            app.buttons["Spiels"].firstMatch.tap()
            try audit(app, "physical-\(theme)-events", for: .contrast)
        }
        app.open(URL(string: "curlplan://stop/kelowna")!)
        app.buttons["curlplan.detail.back"].tap()
        app.buttons["Open settings"].tap(); app.buttons["Ice"].tap(); app.buttons["Close settings"].tap()
    }

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
        app.buttons["Close"].tap()
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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "accessibility-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try app.performAccessibilityAudit(for: types) { issue in
            print("ACCESSIBILITY AUDIT [\(name)]: \(issue.compactDescription); details=\(issue.detailedDescription); element=\(issue.element?.label ?? "none"); frame=\(String(describing: issue.element?.frame)); id=\(issue.element?.identifier ?? "none")")
            return false
        }
    }
}
