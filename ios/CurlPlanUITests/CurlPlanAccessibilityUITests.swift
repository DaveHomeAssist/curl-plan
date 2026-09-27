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

    func testPhysicalProfileActionTargets() throws {
        let app = XCUIApplication(); app.launch()
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        app.open(URL(string: "curlplan://curler/sam")!)
        XCTAssertTrue(app.buttons["Message"].waitForExistence(timeout: 8))
        for control in [app.buttons["curlplan.profile.follow"], app.buttons["Message"]] {
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertTrue(control.isHittable)
        }
        app.buttons["Message"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Message"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A32-profile-targets"; proof.lifetime = .keepAlways; add(proof)
        try audit(app, "profile-action-targets", for: .hitRegion)
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

    func testNativeTextClippingControl() throws {
        let app = XCUIApplication()
        defer { app.terminate(); app.launchArguments = []; app.launch() }
        app.launchArguments = ["--text-accessibility-control"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Plain text control"].waitForExistence(timeout: 5))
        try audit(app, "native-text-control", for: .textClipped)
    }

    func testNativeTabAccessibilityControl() throws {
        let app = XCUIApplication()
        defer { app.terminate(); app.launchArguments = []; app.launch() }
        app.launchArguments = ["--tab-accessibility-control"]
        app.launch()
        XCTAssertTrue(app.staticTexts["First page"].waitForExistence(timeout: 5))
        try audit(app, "native-tab-control")
    }

    func testPhysicalLockerTextClipping() throws {
        let app = XCUIApplication()
        defer { app.terminate(); app.launchArguments = []; app.launch() }
        XCUIDevice.shared.orientation = .portrait
        var auditFailure: Error?
        for large in [false, true] {
            app.launchArguments = large ? ["--large-type-audit"] : []
            app.launch()
            let enter = app.buttons["curlplan.demo.enter"]
            if enter.waitForExistence(timeout: 2) { enter.tap() }
            app.buttons["Locker"].firstMatch.tap()
            app.buttons["curlplan.feed.discover"].tap()
            if large {
                app.buttons["Search feed"].tap()
                let search = app.textFields["Search the feed"]
                search.tap(); search.typeText("Sam Reid")
                if app.buttons["Hide keyboard"].exists { app.buttons["Hide keyboard"].tap() }
            }
            XCTAssertTrue(app.staticTexts["Took the A-final at Kelowna. Ice was lightning all weekend. 🥌"].exists)
            do { try audit(app, "physical-locker-clipping-" + (large ? "large" : "normal"), for: .textClipped) }
            catch { auditFailure = error }
            app.terminate()
        }
        if let auditFailure { throw auditFailure }
    }

    func testPhysicalMainTabAccessibility() throws {
        continueAfterFailure = true
        let app = XCUIApplication(); app.launch()
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        for title in ["Passport", "Locker", "Spiels", "Roster"] {
            let tab = app.buttons[title].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
            if app.buttons["curlplan.detail.back"].exists { app.buttons["curlplan.detail.back"].tap() }
            try audit(app, "physical-main-" + title.lowercased())
        }
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
            // Some Dynamic Type findings refer to elements removed during the audit.
            // Avoid three slow stale-element lookups without suppressing the finding.
            let element = issue.element.flatMap { $0.exists ? $0 : nil }
            print("ACCESSIBILITY AUDIT [\(name)]: \(issue.compactDescription); details=\(issue.detailedDescription); element=\(element?.label ?? "none"); frame=\(String(describing: element?.frame)); id=\(element?.identifier ?? "none")")
            return false
        }
    }
}
