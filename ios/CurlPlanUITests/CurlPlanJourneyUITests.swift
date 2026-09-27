import XCTest

final class CurlPlanJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testEventCreateEditAndDelete() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons["curlplan.event.add"].tap()
        let marker = "Event " + UUID().uuidString.prefix(8)
        app.textFields["Name"].tap(); app.textFields["Name"].typeText(marker); hideAuditKeyboard()
        app.textFields["Location"].tap(); app.textFields["Location"].typeText("Club sheet 2"); hideAuditKeyboard()
        XCTAssertEqual(app.datePickers.count, 2)
        app.buttons["Save"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 4))
        let detail = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.event.details.sp-")).firstMatch
        detail.tap(); app.buttons["Edit event"].tap()
        let name = app.textFields["Name"]
        XCTAssertEqual(name.value as? String, marker)
        name.tap(); name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        name.typeText(" corrected"); hideAuditKeyboard()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[marker + " corrected"].waitForExistence(timeout: 4))
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A11-dated-event"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["Delete event"].tap(); app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[marker + " corrected"].exists)
        app.buttons["Delete event"].tap(); app.alerts.buttons["Delete event"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        XCTAssertFalse(app.staticTexts[marker + " corrected"].exists)
    }

    func testBackupExportAndImportControls() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 8)); tab("Passport").tap()
        if app.buttons["curlplan.detail.back"].exists { app.buttons["curlplan.detail.back"].tap() }
        app.buttons["Open settings"].tap()
        let backup = app.buttons["Backup and restore"]
        for _ in 0..<3 { if backup.isHittable { break }; app.swipeUp() }
        backup.tap()
        XCTAssertTrue(app.buttons["Choose backup to restore"].waitForExistence(timeout: 4))
        app.buttons["Export backup"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        let local = app.cells["DOC.sidebar.item.On My iPad"]
        XCTAssertTrue(local.waitForExistence(timeout: 5)); local.tap()
        let name = "CurlPlan A29 " + UUID().uuidString.prefix(8)
        let filename = app.textFields.firstMatch
        let old = filename.value as? String ?? ""
        filename.tap(); filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + name)
        app.buttons["Move"].tap()
        XCTAssertTrue(app.staticTexts["Backup exported."].waitForExistence(timeout: 8))
        app.buttons["Choose backup to restore"].tap()
        XCTAssertTrue(local.waitForExistence(timeout: 5)); local.tap()
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8)); file.tap()
        XCTAssertTrue(app.buttons["Replace device records"].waitForExistence(timeout: 8))
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A29-restore-preview"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["Replace device records"].tap()
        XCTAssertTrue(app.buttons["curlplan.backup.confirm"].waitForExistence(timeout: 4))
        app.buttons["curlplan.backup.confirm"].tap()
        XCTAssertTrue(app.staticTexts["Records restored. Previous records are available above."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preview previous device records"].exists)
        app.buttons["Done"].tap()
    }

    func testSavedIceReadingLandscapeLayout() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        app.open(URL(string: "curlplan://stop/kelowna")!)
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 8))
        let saved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Sheet A21 ", "A21 draw weight check")).firstMatch
        guard saved.exists else { throw XCTSkip("Requires the preceding physical ice reading journey") }
        for _ in 0..<4 {
            if saved.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(saved.isHittable)
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A21-landscape-screen"; proof.lifetime = .keepAlways; add(proof)
    }

    func testIceReadingDateAndSheetRecovery() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        app.open(URL(string: "curlplan://stop/kelowna")!)
        XCTAssertTrue(app.buttons["Ice read"].waitForExistence(timeout: 8))
        app.buttons["Ice read"].tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 4))
        let marker = "A21 " + UUID().uuidString.prefix(8)
        let sheet = app.textFields["Sheet (optional)"]
        sheet.tap(); sheet.typeText(marker); hideAuditKeyboard()
        let curl = app.textFields["Curl (ft)"]
        if !curl.isHittable { app.swipeUp() }
        curl.tap(); curl.typeText("4"); hideAuditKeyboard()
        let note = app.textFields["Note (optional)"]
        if !note.isHittable { app.swipeUp() }
        note.tap(); note.typeText("A21 draw weight check"); hideAuditKeyboard()
        app.buttons["Save"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 8))
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Sheet " + marker)).firstMatch
        for _ in 0..<4 {
            if saved.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(saved.exists)
        XCTAssertFalse(saved.label.contains("Date not recorded"))
        XCTAssertTrue(saved.label.contains("A21 draw weight check"))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "A21-ice-date-sheet-relaunch"; proof.lifetime = .keepAlways; add(proof)
    }

    func testPersonalResultTotalsAfterCorrectionAndDeletion() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeRight }
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 8))
        tab("Passport").tap()
        if app.buttons["curlplan.detail.back"].exists { app.buttons["curlplan.detail.back"].tap() }
        let games = app.descendants(matching: .any)["curlplan.stats.games"].firstMatch
        XCTAssertTrue(games.waitForExistence(timeout: 4))
        let baseline = try XCTUnwrap(Int(games.value as? String ?? ""))
        tab("Locker").tap(); app.buttons["curlplan.compose.open"].tap()
        let note = app.textFields["What's the word?"]
        guard note.exists, (note.value as? String ?? "").isEmpty else {
            throw XCTSkip("Preserve an existing composer draft")
        }
        let marker = "Score " + UUID().uuidString.prefix(8)
        app.buttons["Result"].tap()
        let score = app.textFields["For"]
        score.tap(); score.typeText("8"); hideAuditKeyboard()
        app.textFields["Against"].tap(); app.textFields["Against"].typeText("2"); hideAuditKeyboard()
        app.textFields["Opponent"].tap(); app.textFields["Opponent"].typeText(marker); hideAuditKeyboard()
        app.buttons["Post"].tap()
        tab("Passport").tap()
        XCTAssertEqual(games.value as? String, String(baseline + 1))
        tab("Locker").tap()
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.post.actions.")).firstMatch
        actions.tap(); app.buttons["Edit post"].tap()
        XCTAssertEqual(app.textFields["Opponent"].value as? String, marker)
        score.tap(); score.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        score.typeText(XCUIKeyboardKey.delete.rawValue + "1"); hideAuditKeyboard()
        app.buttons["Save changes"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        actions.tap(); app.buttons["Edit post"].tap()
        XCTAssertEqual(score.value as? String, "1")
        XCTAssertEqual(app.textFields["Against"].value as? String, "2")
        app.buttons["Close"].tap()
        tab("Passport").tap()
        XCTAssertEqual(games.value as? String, String(baseline + 1))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "A18-personal-result-totals"; proof.lifetime = .keepAlways; add(proof)
        tab("Locker").tap(); actions.tap(); app.buttons["Delete post"].tap()
        app.alerts.buttons["Delete post"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Passport").waitForExistence(timeout: 8)); tab("Passport").tap()
        XCTAssertEqual(games.value as? String, String(baseline))
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

    func testSafariTypingControlOnIPad() throws {
        guard let url = ProcessInfo.processInfo.environment["CURLPLAN_WEB_TYPING_CONTROL_URL"] else {
            throw XCTSkip("Requires a plain textarea control on the physical iPad")
        }
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeRight }
        safari.buttons["NewTabButton"].tap(); safari.buttons["Address"].tap()
        let address = safari.textFields.firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 4))
        address.tap(); address.typeText(url + "\n")
        let field = safari.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap(); field.typeText("WEBFIX 1234")
        XCTAssertEqual(field.value as? String, "WEBFIX 1234", "Plain HTML control, no CurlPlan code")
    }

    func testDetailLinksResumeAndMessageClose() throws {
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        app.open(URL(string: "curlplan://stop/kelowna")!)
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Share club link"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 8))
        app.open(URL(string: "curlplan://curler/sam")!)
        XCTAssertTrue(app.buttons["Share curler link"].waitForExistence(timeout: 8))
        app.buttons["Message"].tap()
        XCTAssertTrue(app.buttons["curlplan.thread.close"].waitForExistence(timeout: 3))
        app.buttons["curlplan.thread.close"].tap()
        XCTAssertTrue(app.buttons["Share curler link"].exists)
        app.open(URL(string: "curlplan://stop/missing")!)
        XCTAssertTrue(app.alerts["Link unavailable"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        tab("Passport").tap()
        if app.buttons["curlplan.detail.back"].exists { app.buttons["curlplan.detail.back"].tap() }
        app.buttons["Open settings"].tap()
        XCTAssertTrue(app.buttons["curlplan.classic.open"].exists)
        app.buttons["curlplan.classic.open"].tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.buttons["Game Planner"].waitForExistence(timeout: 12))
        app.activate()
        XCTAssertTrue(app.buttons["Close settings"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "A10-classic-return"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["Close settings"].tap()
    }

    // Opt-in physical iPad check against a bounded local preview URL.
    func testWebPostRecoveryOnPreparedIPad() throws {
        guard let previewURL = ProcessInfo.processInfo.environment["CURLPLAN_WEB_AUDIT_URL"] else {
            throw XCTSkip("Requires a physical iPad Safari preview URL")
        }
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .landscapeRight }
        if safari.textViews["Discard this draft? Published records stay unchanged."].exists { safari.buttons["OK"].tap() }
        safari.buttons["NewTabButton"].tap()
        safari.buttons["Address"].tap()
        let address = safari.textFields.firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 4))
        address.tap(); address.typeText(previewURL + "\n")
        let demo = safari.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'demo'")).firstMatch
        if demo.waitForExistence(timeout: 3) { demo.tap() }
        let locker = safari.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Locker")).firstMatch
        XCTAssertTrue(locker.waitForExistence(timeout: 10))
        locker.tap(); safari.buttons["New post"].tap()
        let body = safari.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 4))
        if body.value as? String == "WEBFIX " {
            safari.buttons["Discard draft"].tap(); safari.buttons["OK"].tap()
            safari.buttons["New post"].tap()
        }
        guard (body.value as? String ?? "").isEmpty || (body.value as? String ?? "").contains("Share a thought") else {
            throw XCTSkip("Preserve existing web draft")
        }
        let original = "WEBFIX " + UUID().uuidString.prefix(8)
        body.tap()
        for character in original { body.typeText(String(character)) }
        XCTAssertEqual(body.value as? String, original)
        let hide = safari.buttons["Hide keyboard"].firstMatch
        if hide.exists { hide.tap() }
        safari.buttons["Close"].firstMatch.tap()
        safari.buttons["New post"].tap()
        XCTAssertEqual(body.value as? String, original)
        safari.buttons["Post"].firstMatch.tap()
        XCTAssertTrue(safari.staticTexts[original].waitForExistence(timeout: 5))
        safari.buttons["Post actions"].firstMatch.tap(); safari.buttons["Edit post"].tap()
        XCTAssertEqual(body.value as? String, original)
        body.tap(); body.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.2)).tap()
        body.typeText(" corrected")
        if hide.exists { hide.tap() }
        safari.buttons["Save changes"].tap()
        XCTAssertTrue(safari.staticTexts[original + " corrected"].waitForExistence(timeout: 5))
        let proof = XCTAttachment(screenshot: safari.webViews.firstMatch.screenshot())
        proof.name = "A2-web-corrected-note"; proof.lifetime = .keepAlways; add(proof)
        safari.buttons["Post actions"].firstMatch.tap(); safari.buttons["Delete post"].tap()
        XCTAssertTrue(safari.buttons["OK"].waitForExistence(timeout: 3))
        safari.buttons["OK"].tap()
        XCTAssertFalse(safari.staticTexts[original + " corrected"].exists)
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
