import XCTest

final class CurlPlanJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testOwnedNoteCorrectionAndDraftRecovery() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeRight }
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8))
        tab("Locker").tap()
        app.buttons["curlplan.compose.open"].tap()
        let field = app.textFields["What's the word?"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let existing = field.value as? String ?? ""
        guard existing.isEmpty else { throw XCTSkip("Preserve an existing composer draft; use a dedicated empty draft to run this test") }
        let original = "CPFIX typo " + UUID().uuidString.prefix(8)
        field.tap(); field.typeText(original)
        hideAuditKeyboard()
        // Real interactive dismissal: the draft must survive the sheet and process.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.2)).tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8))
        tab("Locker").tap(); app.buttons["curlplan.compose.open"].tap()
        XCTAssertEqual(field.value as? String, original)
        app.buttons["Post"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 4))
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.post.actions.")).firstMatch
        actions.tap(); app.buttons["Edit post"].tap()
        XCTAssertEqual(field.value as? String, original)
        let corrected = original.replacingOccurrences(of: "typo", with: "corrected")
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
        field.typeText(corrected)
        hideAuditKeyboard()
        app.buttons["Save changes"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertTrue(app.staticTexts[corrected].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts[original].exists)
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A2-corrected-note-relaunch"; proof.lifetime = .keepAlways; add(proof)
        actions.tap(); app.buttons["Delete post"].tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[corrected].exists)
        actions.tap(); app.buttons["Delete post"].tap()
        app.alerts.buttons["Delete post"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertFalse(app.staticTexts[corrected].exists)
        app.buttons["curlplan.compose.open"].tap()
        XCTAssertEqual(field.value as? String, "", "Published/deleted drafts must not reappear")
        app.buttons["Close"].tap()
    }

    func testClubReviewCorrectionAndRecovery() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeRight }
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 8))
        tab("Passport").tap(); app.buttons["curlplan.stop.kelowna"].tap()
        app.buttons["Write review"].tap()
        let field = app.textFields["Review"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        guard (field.value as? String ?? "").isEmpty else { throw XCTSkip("Preserve existing review draft") }
        let original = "Review " + UUID().uuidString.prefix(8)
        field.tap(); field.typeText(original); hideAuditKeyboard()
        app.buttons["Save"].tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.review.actions.")).firstMatch
        for _ in 0..<5 {
            if actions.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(actions.isHittable)
        actions.tap(); app.buttons["Edit review"].tap()
        XCTAssertEqual(field.value as? String, original)
        field.tap(); field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(" corrected"); hideAuditKeyboard()
        app.buttons["2 stars"].tap()
        app.buttons["Close"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 8))
        tab("Passport").tap(); app.buttons["curlplan.stop.kelowna"].tap()
        for _ in 0..<5 {
            if actions.isHittable { break }
            app.swipeUp()
        }
        actions.tap(); app.buttons["Edit review"].tap()
        XCTAssertEqual(field.value as? String, original + " corrected")
        XCTAssertEqual(app.buttons["2 stars"].value as? String, "Selected rating")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[original + " corrected"].waitForExistence(timeout: 3))
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A22-corrected-review"; proof.lifetime = .keepAlways; add(proof)
        actions.tap(); app.buttons["Delete review"].tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[original + " corrected"].exists)
        actions.tap(); app.buttons["Delete review"].tap()
        app.alerts.buttons["Delete review"].tap()
        XCTAssertFalse(app.staticTexts[original + " corrected"].exists)
    }

    private func hideAuditKeyboard() {
        let hide = app.buttons["Hide keyboard"].firstMatch
        if hide.waitForExistence(timeout: 1) { hide.tap() }
    }

    func testDemoTabsDetailsAndRelaunch() {
        let enter = app.buttons["curlplan.demo.enter"]
        if !enter.waitForExistence(timeout: 3) {
            // Repeat on an installed demo without deleting its saved data.
            XCTAssertTrue(tab("Passport").waitForExistence(timeout: 10))
            tab("Passport").tap()
            app.buttons["Open settings"].tap()
            app.buttons["Sign out"].tap()
        }
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "Signed-out launch must show the demo gate")
        capture("demo-gate")
        enter.tap()

        let passport = tab("Passport")
        XCTAssertTrue(passport.waitForExistence(timeout: 10), "Passport tab must be reachable")
        XCTAssertTrue(app.buttons["curlplan.stop.kelowna"].exists)
        XCTAssertFalse(app.staticTexts["Locker Room"].exists, "Inactive tab content must not be exposed")
        capture("passport")

        tapAfterScrolling(app.buttons["curlplan.stop.kelowna"], name: "Kelowna stop")
        XCTAssertTrue(app.buttons["curlplan.detail.back"].waitForExistence(timeout: 5))
        scrollUntilHittable(app.staticTexts["ICE READ"], name: "Ice read")
        capture("stop-detail")
        openTab("locker", title: "Locker Room")
        tab("Passport").tap()
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
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 10), "Demo session must survive relaunch")
        openTab("roster", title: "Roster")
        tapAfterScrolling(app.buttons["curlplan.curler.sam"], name: "Sam Reid profile after relaunch")
        XCTAssertEqual(app.buttons["curlplan.profile.follow"].label, after, "Follow state must survive relaunch")
        capture("relaunch-profile")
    }

    private func openTab(_ id: String, title: String) {
        let tabButton = tab(title == "Locker Room" ? "Locker" : title)
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "\(title) tab must be reachable")
        tabButton.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(title) screen must render")
        capture("tab-\(id)")
    }

    private func tab(_ title: String) -> XCUIElement {
        let phoneTab = app.tabBars.buttons[title]
        if phoneTab.exists { return phoneTab }
        // iPadOS 18 exposes its top tab strip as nested buttons, not a TabBar.
        return app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
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
