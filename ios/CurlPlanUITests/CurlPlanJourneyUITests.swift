import XCTest

final class CurlPlanJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testEventScreenflowOrientationsAndLargeType() throws {
        defer { app.terminate(); app.launchArguments = []; app.launch(); XCUIDevice.shared.orientation = .portrait }
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        for large in [false, true] {
            app.terminate(); app.launchArguments = large ? ["--large-type-audit"] : []; app.launch()
            for landscape in [false, true] {
                XCUIDevice.shared.orientation = landscape ? .landscapeRight : .portrait
                XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
                tapAfterScrolling(app.buttons["curlplan.event.details.sp2"], name: "Event detail")
                let detailScroll = app.scrollViews["curlplan.event.detail.scroll"]
                func reveal(_ element: XCUIElement) {
                    for _ in 0..<10 {
                        if element.exists && detailScroll.frame.contains(element.frame) && element.isHittable { return }
                        if element.exists && element.frame.midY < detailScroll.frame.minY { detailScroll.swipeDown() }
                        else { detailScroll.swipeUp() }
                    }
                    XCTAssertTrue(element.exists && detailScroll.frame.contains(element.frame) && element.isHittable, "Control must be fully visible inside the detail sheet")
                }
                let going = app.buttons["curlplan.attendance.Going"], considering = app.buttons["curlplan.attendance.Considering"]
                reveal(going)
                XCTAssertFalse(app.staticTexts["Format"].exists, "Planning is initially collapsed")
                if large { XCTAssertGreaterThan(considering.frame.minY, going.frame.minY, "Large text uses stacked attendance controls") }
                let disclosure = app.buttons["curlplan.event.planning.details"]
                reveal(disclosure); disclosure.tap()
                reveal(app.staticTexts["Format"])
                XCTAssertTrue(app.staticTexts["Entry requirements"].exists)
                reveal(disclosure); disclosure.tap()
                XCTAssertFalse(app.staticTexts["Format"].exists)
                let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                proof.name = "A31-event-" + (large ? "large-" : "normal-") + (landscape ? "landscape" : "portrait")
                proof.lifetime = .keepAlways; add(proof)
                reveal(app.buttons["Done"]); app.buttons["Done"].tap()
            }
        }
    }

    func testRosterContactAvailabilityLifecycle() throws {
        XCUIDevice.shared.orientation = .portrait
        let marker = "SPARE20260927B"
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Roster").waitForExistence(timeout: 8)); tab("Roster").tap()
        if app.buttons["curlplan.detail.back"].exists { app.buttons["curlplan.detail.back"].tap() }
        XCTAssertFalse(app.staticTexts[marker].exists, "Preserve any existing matching contact")
        app.buttons["curlplan.roster.add"].tap()
        func fill(_ label: String, _ value: String) {
            let field = app.textFields[label]
            scrollUntilHittable(field, name: label); field.tap(); field.typeText(value); hideAuditKeyboard()
        }
        fill("Name", marker)
        app.buttons["Second"].tap()
        fill("Club", "A23 Test Club"); fill("Province", "BC")
        tapAfterScrolling(app.switches["Spare contact"], name: "Spare flag")
        fill("Contact details", "test@example.invalid")
        tapAfterScrolling(app.descendants(matching: .any)["curlplan.roster.availability"].firstMatch, name: "Availability")
        app.buttons["Available"].tap()
        fill("Available from (YYYY-MM-DD)", "2026-10-01")
        fill("Through (YYYY-MM-DD)", "2026-10-03")
        fill("Availability notes", "Evenings after 6")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 4)); app.staticTexts[marker].tap()
        XCTAssertTrue(app.staticTexts["test@example.invalid"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Spare · Available: 2026-10-01 to 2026-10-03 (your note)"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["test@example.invalid"].waitForExistence(timeout: 8))
        tapAfterScrolling(app.buttons["Edit contact"], name: "Edit contact")
        let notes = app.textFields["Availability notes"]
        scrollUntilHittable(notes, name: "Availability notes"); notes.tap()
        notes.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        notes.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Evenings after 6".count))
        notes.typeText("Evenings after 7"); hideAuditKeyboard(); app.buttons["Save"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Evenings after 7"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Saved on your roster"].exists)
        XCTAssertTrue(app.staticTexts["No shared club history recorded."].exists)
        XCTAssertTrue(app.staticTexts["No game history recorded for this contact."].exists)
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A23-private-spare-contact"; proof.lifetime = .keepAlways; add(proof)
        tapAfterScrolling(app.buttons["Delete contact"], name: "Delete contact")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Evenings after 7"].exists)
        app.buttons["Delete contact"].tap(); app.alerts.buttons["Delete contact"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Roster").waitForExistence(timeout: 8)); tab("Roster").tap()
        XCTAssertFalse(app.staticTexts[marker].exists)
    }

    func testLocalAttendanceIntentSurvivesRelaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        func openSample() {
            XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
            tapAfterScrolling(app.buttons["curlplan.event.details.sp2"], name: "Sample event details")
            scrollUntilHittable(app.buttons["curlplan.attendance.Going"], name: "Attendance choices")
        }
        openSample()
        let choices = ["Going", "Considering", "Not going"]
        let original = try XCTUnwrap(choices.first { app.buttons["curlplan.attendance." + $0].value as? String == "Selected" })
        for choice in choices {
            app.buttons["curlplan.attendance." + choice].tap()
            app.terminate(); app.launch(); openSample()
            XCTAssertEqual(app.buttons["curlplan.attendance." + choice].value as? String, "Selected")
            XCTAssertTrue(app.staticTexts["Saved on this device only; this does not register you with the organizer."].exists)
        }
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A3-local-attendance"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["curlplan.attendance." + original].tap()
        app.terminate(); app.launch(); openSample()
        XCTAssertEqual(app.buttons["curlplan.attendance." + original].value as? String, "Selected")
    }

    func testLessonTransferAndLinkedResult() throws {
        XCUIDevice.shared.orientation = .portrait
        let marker = "FLOW20260927A", lesson = "Flow lesson balanced finish", resultNote = "Flow result 20260927A"
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        if !app.staticTexts[marker].exists {
            app.buttons["curlplan.event.add"].tap()
            let name = app.textFields["Name"], current = name.value as? String ?? ""
            guard ["", "League game", "Draft 11A1F039", marker].contains(current) else { throw XCTSkip("Preserve event draft") }
            name.tap(); name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)); name.typeText(marker); hideAuditKeyboard()
            let location = app.textFields["Location"]
            let oldLocation = location.value as? String ?? ""
            location.tap(); location.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            location.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldLocation.count)); location.typeText("Flow club"); hideAuditKeyboard()
            app.buttons["Save"].tap()
        }
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 4))
        tab("Locker").tap()
        if !app.staticTexts[lesson].exists {
            app.buttons["curlplan.compose.open"].tap()
            let note = app.textFields["What's the word?"]
            guard note.exists, ["", lesson].contains(note.value as? String ?? "") else { throw XCTSkip("Preserve composer draft") }
            if note.value as? String != lesson { note.tap(); note.typeText(lesson); hideAuditKeyboard() }
            app.buttons["Post"].tap()
        }
        XCTAssertTrue(app.staticTexts[lesson].waitForExistence(timeout: 4))
        app.buttons["Use in game preparation"].firstMatch.tap()
        app.descendants(matching: .any)["curlplan.prepare.event"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", marker)).firstMatch.tap()
        app.buttons["Add lesson to preparation"].tap()
        XCTAssertTrue(app.staticTexts["Lesson saved to game preparation."].waitForExistence(timeout: 4))
        app.buttons["View game preparation"].tap()
        XCTAssertTrue(app.staticTexts["Lesson for this game: " + lesson].waitForExistence(timeout: 4))
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.event.details.sp-")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Lesson for this game: " + lesson].exists)
        app.terminate(); app.launch(); XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        if !app.staticTexts[resultNote].exists {
            app.buttons["curlplan.compose.open"].tap(); app.buttons["Result"].tap()
            app.descendants(matching: .any)["curlplan.result.event"].firstMatch.tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", marker)).firstMatch.tap()
            for (label,value) in [("For","8"),("Against","3"),("Opponent","Flow opponent"),("Note (optional)",resultNote)] {
                let field=app.textFields[label]; field.tap(); field.typeText(value); hideAuditKeyboard()
            }
            app.buttons["Post"].tap()
        }
        app.terminate(); app.launch(); XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertTrue(app.staticTexts[resultNote].waitForExistence(timeout: 4))
        app.buttons["Event: " + marker].tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "8–3 vs Flow opponent")).firstMatch.exists)
        let proof=XCTAttachment(screenshot:XCUIScreen.main.screenshot());proof.name="A16-A20-linked-event";proof.lifetime = .keepAlways;add(proof)
        app.buttons["Delete event"].tap(); app.alerts.buttons["Delete event"].tap()
        app.terminate(); app.launch(); XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertTrue(app.staticTexts["Event: " + marker + " (removed)"].waitForExistence(timeout: 4))
        for text in [resultNote, lesson] {
            XCTAssertTrue(app.staticTexts[text].exists)
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.post.actions.")).firstMatch.tap()
            app.buttons["Delete post"].tap(); app.alerts.buttons["Delete post"].tap()
        }
        app.terminate(); app.launch(); XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertFalse(app.staticTexts[resultNote].exists); XCTAssertFalse(app.staticTexts[lesson].exists)
    }

    func testVisitDraftRecoveryAndDiscard() throws { try verifyContributionDraftRecovery(["Log visit"]) }
    func testIceDraftRecoveryAndDiscard() throws { try verifyContributionDraftRecovery(["Ice read"]) }

    private func verifyContributionDraftRecovery(_ actions: [String]) throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        for action in actions {
            app.open(URL(string: "curlplan://stop/kelowna")!)
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 8)); app.buttons[action].tap()
            let note = app.textFields["Note (optional)"]
            XCTAssertTrue(note.waitForExistence(timeout: 4))
            guard (note.value as? String ?? "").isEmpty else { throw XCTSkip("Preserve existing contribution draft") }
            if action == "Ice read" {
                guard ["", "4–5"].contains(app.textFields["Curl (ft)"].value as? String ?? ""),
                      ["", "e.g. 3 or A"].contains(app.textFields["Sheet (optional)"].value as? String ?? "") else { throw XCTSkip("Preserve existing ice draft") }
            } else {
                guard app.textFields["Date"].value as? String == "Today" else { throw XCTSkip("Preserve existing visit draft") }
            }
            let marker = "Recovery " + UUID().uuidString.prefix(8)
            note.tap(); note.typeText(marker); hideAuditKeyboard()
            app.buttons["Close"].tap(); app.terminate(); app.launch()
            app.open(URL(string: "curlplan://stop/kelowna")!)
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 8)); app.buttons[action].tap()
            XCTAssertEqual(app.textFields["Note (optional)"].value as? String, marker)
            app.buttons["Discard draft"].tap(); app.alerts.buttons["Keep draft"].tap()
            XCTAssertEqual(app.textFields["Note (optional)"].value as? String, marker)
            let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            proof.name = "A30-" + action + "-draft"; proof.lifetime = .keepAlways; add(proof)
            app.buttons["Discard draft"].tap(); app.alerts.buttons["Discard draft"].tap()
            app.terminate(); app.launch(); app.open(URL(string: "curlplan://stop/kelowna")!)
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: 8)); app.buttons[action].tap()
            XCTAssertEqual(app.textFields["Note (optional)"].value as? String, "")
            app.buttons["Close"].tap(); app.terminate(); app.launch()
        }
    }

    func testPracticeCreateRecoverEditAndDelete() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        app.buttons["curlplan.compose.open"].tap()
        let note = app.textFields["What's the word?"]
        guard note.exists, (note.value as? String ?? "").isEmpty else {
            throw XCTSkip("Preserve existing composer draft")
        }
        app.buttons["Practice"].tap()
        let marker = "Practice " + UUID().uuidString.prefix(8)
        for (label, value) in [("Practice date (YYYY-MM-DD)", "2026-09-27"), ("Duration (minutes)", "45"),
                               ("Drills", marker), ("Focus", "Release"), ("Observations", "Balanced finish")] {
            let field = app.textFields[label]
            field.tap(); field.typeText(value); hideAuditKeyboard()
        }
        app.buttons["Close"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        app.buttons["curlplan.compose.open"].tap()
        XCTAssertEqual(app.textFields["Drills"].value as? String, marker)
        XCTAssertEqual(app.textFields["Duration (minutes)"].value as? String, "45")
        XCTAssertEqual(app.textFields["Observations"].value as? String, "Balanced finish")
        app.buttons["Post"].tap()
        let summary = "Practice · 2026-09-27 · 45 minutes\nFocus: Release\nDrills: " + marker + "\nBalanced finish"
        XCTAssertTrue(app.staticTexts[summary].waitForExistence(timeout: 4))
        let actions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "curlplan.post.actions.")).firstMatch
        actions.tap(); app.buttons["Edit post"].tap()
        let observations = app.textFields["Observations"]
        XCTAssertEqual(observations.value as? String, "Balanced finish")
        observations.tap(); observations.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        observations.typeText(" next game"); hideAuditKeyboard()
        app.buttons["Save changes"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertTrue(app.staticTexts[summary + " next game"].waitForExistence(timeout: 4))
        app.buttons["Use in game preparation"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Balanced finish next game"].waitForExistence(timeout: 4))
        app.buttons["Cancel"].tap()
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A19-practice-recovered"; proof.lifetime = .keepAlways; add(proof)
        actions.tap(); app.buttons["Delete post"].tap(); app.alerts.buttons["Delete post"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Locker").waitForExistence(timeout: 8)); tab("Locker").tap()
        XCTAssertFalse(app.staticTexts[summary + " next game"].exists)
    }

    func testEventPlanningFieldsAreReachable() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons["curlplan.event.add"].tap()
        let disclosure = app.buttons["Event details and trip planning"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 4))
        disclosure.tap()
        XCTAssertTrue(app.textFields["Format"].exists)
        XCTAssertTrue(app.textFields["Entry requirements"].exists)
        XCTAssertTrue(app.textFields["Organizer"].exists)
        XCTAssertTrue(app.textFields["Draw schedule"].exists)
        XCTAssertTrue(app.textFields["Travel"].exists)
        XCTAssertTrue(app.textFields["Accommodation"].exists)
        XCTAssertTrue(app.textFields["Team arrangements"].exists)
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A13-A14-planning-fields"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["Close"].tap()
    }

    func testEventDraftSurvivesRelaunchAndDiscard() throws {
        XCUIDevice.shared.orientation = .portrait
        let enter = app.buttons["curlplan.demo.enter"]
        if enter.waitForExistence(timeout: 2) { enter.tap() }
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons["curlplan.event.add"].tap()
        let name = app.textFields["Name"]
        let marker = "Draft 11A1F039"
        let current = name.value as? String ?? ""
        guard current.isEmpty || current == "League game" || current == marker else {
            throw XCTSkip("Preserve existing event draft")
        }
        if current != marker {
            name.tap(); name.typeText(marker); hideAuditKeyboard()
            app.textFields["Location"].tap(); app.textFields["Location"].typeText("Sheet 4"); hideAuditKeyboard()
        }
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons["curlplan.event.add"].tap()
        XCTAssertEqual(app.textFields["Name"].value as? String, marker)
        XCTAssertEqual(app.textFields["Location"].value as? String, "Sheet 4")
        let proof = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        proof.name = "A30-event-draft-recovery"; proof.lifetime = .keepAlways; add(proof)
        app.buttons["Discard draft"].tap()
        app.buttons["Keep draft"].tap()
        XCTAssertEqual(app.textFields["Name"].value as? String, marker)
        app.buttons["Discard draft"].tap()
        app.buttons["curlplan.event.discard.confirm"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["Close"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 4), .completed)
        app.buttons["curlplan.event.add"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 4))
        XCTAssertNotEqual(app.textFields["Name"].value as? String, marker)
        app.buttons["Close"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(tab("Spiels").waitForExistence(timeout: 8)); tab("Spiels").tap()
        app.buttons["curlplan.event.add"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 4))
        XCTAssertNotEqual(app.textFields["Name"].value as? String, marker)
        app.buttons["Close"].tap()
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
