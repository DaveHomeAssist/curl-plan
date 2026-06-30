import XCTest

final class CurlPlanPrimaryScreenflowUITests: XCTestCase {
    private var app: XCUIApplication!

    // Deployed dev account backend (dominic tailnet). Used only by the opt-in
    // account screenflow test. Cleartext http needs an ATS exception or TLS to
    // actually connect — see testAccountCredentialScreenflow...'s skip guard.
    private let accountBackendURL = "http://dominic.tailae148c.ts.net:8787"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-curlplan-ui-reset"]
        if name.contains("testSmallScreenAccessibilityPrimaryControlsRemainReachable") {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityM"
            ]
        }
        if name.contains("AccountCredentialScreenflow") {
            app.launchEnvironment["CURLPLAN_ACCOUNT_BACKEND_URL"] = accountBackendURL
        }
        app.launch()
    }

    func testCleanInstallLockerLoopSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openLocker()
        toggleAttendanceTwice()
        openBrierPatchDetails()
        let attending = app.staticTexts["4 ATTENDING"]
        for _ in 0..<5 where !attending.exists {
            app.swipeUp()
        }
        XCTAssertTrue(attending.waitForExistence(timeout: 4))
        app.buttons["Done"].tap()
        openLocker()
        logResult(opponent: "Truth Test CC",
                  scoreFor: "9",
                  scoreAgainst: "4",
                  note: "UI proof result",
                  stopID: "kelowna",
                  curlerID: "sam")
        assertLockerShowsResult(opponent: "Truth Test CC", note: "UI proof result")
        editFirstResult(opponent: "Corrected Truth CC", scoreFor: "4", scoreAgainst: "7", note: "UI corrected result")
        assertLockerShowsResult(opponent: "Corrected Truth CC", note: "UI corrected result")
        deleteAndUndoFirstResult(note: "UI corrected result")
        assertLockerShowsResult(opponent: "Corrected Truth CC", note: "UI corrected result")
        openPassport()
        assertPassportStat("curlplan.passport.stat.games", contains: "41")
        assertPassportStat("curlplan.passport.stat.win", contains: "68%")
        openStopFromPassport("kelowna")
        assertStopShowsLinkedResult(opponent: "Corrected Truth CC", score: "4-7")
        openCurlerFromCurrentStop(id: "sam", name: "Sam Reid")
        assertProfileShowsLinkedResult(score: "4-7", context: "Kelowna Bonspiel")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openLocker()
        assertLockerShowsResult(opponent: "Corrected Truth CC", note: "UI corrected result")
        openPassport()
        assertPassportStat("curlplan.passport.stat.games", contains: "41")
        assertPassportStat("curlplan.passport.stat.win", contains: "68%")
        openStopFromPassport("kelowna")
        assertStopShowsLinkedResult(opponent: "Corrected Truth CC", score: "4-7")
        openCurlerFromCurrentStop(id: "sam", name: "Sam Reid")
        assertProfileShowsLinkedResult(score: "4-7", context: "Kelowna Bonspiel")
    }

    func testBlankSeasonRosterLoopSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.start-blank-season"].waitForExistence(timeout: 6))
        app.textFields["curlplan.field.your-name"].tap()
        app.textFields["curlplan.field.your-name"].typeText("Truth User")
        app.textFields["curlplan.field.home-rink"].tap()
        app.textFields["curlplan.field.home-rink"].typeText("Proof Curling Club")
        app.textFields["curlplan.field.province"].tap()
        app.textFields["curlplan.field.province"].typeText("ON")
        app.buttons["curlplan.setup.start-blank-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openRoster()
        let addCurler = app.buttons["curlplan.addCurler"]
        XCTAssertTrue(addCurler.waitForExistence(timeout: 4))
        addCurler.tap()

        let name = app.textFields["curlplan.field.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        name.tap()
        name.typeText("Ivy Truth")
        app.textFields["curlplan.field.club"].tap()
        app.textFields["curlplan.field.club"].typeText("Proof CC")
        app.textFields["curlplan.field.province"].tap()
        app.textFields["curlplan.field.province"].typeText("BC")
        app.staticTexts["Add to roster"].tap()
        app.buttons["curlplan.sheet.save"].tap()

        assertRosterShowsCurler()

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openRoster()
        assertRosterShowsCurler()
    }

    func testStopVisitLoopSurvivesRelaunchAndCanEnd() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openStopFromPassport("kelowna")
        let startVisit = app.buttons["curlplan.stop.startVisit"]
        XCTAssertTrue(startVisit.waitForExistence(timeout: 4))
        startVisit.tap()
        XCTAssertTrue(app.staticTexts["Start visit"].waitForExistence(timeout: 4))
        tapSheetButton("curlplan.visit.curler.carter")
        let visitNote = app.textFields["curlplan.field.visit-note"]
        XCTAssertTrue(visitNote.waitForExistence(timeout: 4))
        visitNote.tap()
        visitNote.typeText("Met Carter during UI proof")
        app.buttons["curlplan.sheet.save"].tap()
        XCTAssertTrue(app.buttons["curlplan.stop.endVisit"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Visit started."].waitForExistence(timeout: 4))
        assertStopShowsCurler(name: "Bryn Carter", id: "carter")
        openCurlerFromCurrentStop(id: "carter", name: "Bryn Carter")
        assertProfileShowsSharedRink("Kelowna Curling Club")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openStopFromPassport("kelowna")
        assertStopShowsCurler(name: "Bryn Carter", id: "carter")
        let endVisit = app.buttons["curlplan.stop.endVisit"]
        XCTAssertTrue(endVisit.waitForExistence(timeout: 4))
        endVisit.tap()
        XCTAssertTrue(app.buttons["curlplan.stop.startVisit"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Visit ended."].waitForExistence(timeout: 4))
    }

    func testProfileShareAndDeleteCleanReferencesAcrossRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openStopFromPassport("kelowna")
        openCurlerFromCurrentStop(id: "sam", name: "Sam Reid")
        tapButton("curlplan.profile.copyShare")
        XCTAssertTrue(app.staticTexts["curlplan.profile.notice"].waitForExistence(timeout: 4))
        assertProfileShareText(name: "Sam Reid", club: "Vernon CC")

        tapButton("curlplan.profile.delete")
        confirmProfileDelete()
        XCTAssertTrue(app.buttons["curlplan.stop.startVisit"].waitForExistence(timeout: 2) || app.buttons["curlplan.stop.endVisit"].waitForExistence(timeout: 2))
        assertStopDoesNotShowCurler(id: "sam", name: "Sam Reid")
        openRoster()
        assertRosterSearchDoesNotFindCurler(id: "sam", name: "Sam Reid")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openStopFromPassport("kelowna")
        assertStopDoesNotShowCurler(id: "sam", name: "Sam Reid")
        openRoster()
        assertRosterSearchDoesNotFindCurler(id: "sam", name: "Sam Reid")
    }

    func testBonspielScorecardLoopSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openBrierPatchDetails()
        tapButton("curlplan.bonspiel.bp-g1.confirm")
        XCTAssertTrue(app.staticTexts["Game needs 6 completed ends or a concession."].waitForExistence(timeout: 4))
        tapButton("curlplan.bonspiel.bp-g1.concede")
        XCTAssertTrue(app.staticTexts["Result flags saved."].waitForExistence(timeout: 4))
        tapButton("curlplan.bonspiel.bp-g1.confirm")
        XCTAssertTrue(app.staticTexts["Local result confirmed"].waitForExistence(timeout: 4))

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openBrierPatchDetails()
        XCTAssertTrue(app.staticTexts["Local result confirmed"].waitForExistence(timeout: 4))
        app.buttons["Done"].tap()

        openLocker()
        let scorecardPost = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Local scorecard")).firstMatch
        XCTAssertTrue(scorecardPost.waitForExistence(timeout: 4))
    }

    func testBonspielScorecardEndScoringEdgesSurviveRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openBrierPatchDetails()
        tapButton("curlplan.bonspiel.bp-g2.scoreA")
        assertBonspielGameScore(gameID: "bp-g2", contains: "1-0")
        tapButton("curlplan.bonspiel.bp-g2.blank")
        assertBonspielGameScore(gameID: "bp-g2", contains: "1-0")
        tapButton("curlplan.bonspiel.bp-g2.scoreB")
        assertBonspielGameScore(gameID: "bp-g2", contains: "1-1")
        tapButton("curlplan.bonspiel.bp-g2.scoreA")
        tapButton("curlplan.bonspiel.bp-g2.scoreB")
        tapButton("curlplan.bonspiel.bp-g2.blank")
        tapButton("curlplan.bonspiel.bp-g2.scoreA")
        tapButton("curlplan.bonspiel.bp-g2.scoreB")
        assertBonspielGameScore(gameID: "bp-g2", contains: "3-3")
        tapButton("curlplan.bonspiel.bp-g2.confirm")
        assertBonspielGameMessage(contains: "Tied games need an extra end")

        tapButton("curlplan.bonspiel.bp-g2.scoreA")
        assertBonspielGameScore(gameID: "bp-g2", contains: "4-3")
        tapButton("curlplan.bonspiel.bp-g2.confirm")
        XCTAssertTrue(app.staticTexts["Local result confirmed"].waitForExistence(timeout: 4))

        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openBrierPatchDetails()
        assertBonspielGameScore(gameID: "bp-g2", contains: "4-3")
        assertBonspielGameStatus(gameID: "bp-g2", contains: "Finalized")
    }

    func testBonspielForfeitResultSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openBrierPatchDetails()
        tapButton("curlplan.bonspiel.bp-g1.forfeit")
        XCTAssertTrue(app.staticTexts["Result flags saved."].waitForExistence(timeout: 4))
        tapButton("curlplan.bonspiel.bp-g1.confirm")
        XCTAssertTrue(app.staticTexts["Local result confirmed"].waitForExistence(timeout: 4))

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openBrierPatchDetails()
        assertBonspielGameStatus(gameID: "bp-g1", contains: "Forfeit")
    }

    func testBonspielRosterAndLineupManagementSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openBrierPatchDetails()
        tapButton("curlplan.bonspiel.roster.add.team-mercer")
        let name = app.textFields["curlplan.field.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 4))
        name.tap()
        name.typeText("Lineup Spare")
        app.buttons["curlplan.sheet.save"].tap()
        XCTAssertTrue(app.staticTexts["Team member added."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Lineup Spare"].waitForExistence(timeout: 4))

        app.buttons["Remove Lineup Spare"].tap()
        XCTAssertTrue(app.staticTexts["Team member removed."].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["Lineup Spare"].waitForExistence(timeout: 2))

        tapButton("curlplan.bonspiel.roster.remove.tm-sam")
        XCTAssertTrue(app.staticTexts["Member is locked into a submitted lineup. Record a lineup change instead."].waitForExistence(timeout: 4))

        tapButton("curlplan.bonspiel.bp-g2.invalid.team-mercer")
        assertBonspielGameMessage(contains: "Lineup needs 4 players")
        tapButton("curlplan.bonspiel.bp-g2.submit.team-mercer")
        assertBonspielGameMessage(contains: "Lineup submitted.")
        tapButton("curlplan.bonspiel.bp-g2.submit.team-carter")
        assertBonspielGameMessage(contains: "Lineup submitted.")
        tapButton("curlplan.bonspiel.bp-g2.lockLineup")
        assertBonspielGameMessage(contains: "Lineup locked.")
        tapButton("curlplan.bonspiel.bp-g2.submit.team-mercer")
        assertBonspielGameMessage(contains: "Lineup is locked")

        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openBrierPatchDetails()
        assertBonspielGameStatus(gameID: "bp-g2", contains: "Lineup locked")
    }

    func testSettingsClearAndResetRecoveryLoop() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openSettings()
        app.buttons["curlplan.settings.clear-season"].tap()
        app.buttons["curlplan.settings.confirm.clearSeason"].firstMatch.tap()
        app.buttons["curlplan.settings.done"].tap()
        XCTAssertTrue(app.staticTexts["No stops yet"].waitForExistence(timeout: 4))

        openSettings()
        app.buttons["curlplan.settings.reset-demo"].tap()
        app.buttons["curlplan.settings.confirm.resetDemo"].firstMatch.tap()
        app.buttons["curlplan.settings.done"].tap()
        openStopFromPassport("kamloops")
    }

    func testExportClearImportRecoveryLoopSurvivesRelaunch() throws {
        startBlankSeason(name: "Recovery User", homeClub: "Archive Curling Club", province: "MB")

        openRoster()
        addRosterCurler(name: "Restore Truth", club: "Archive CC", province: "MB")
        assertRosterShowsCurler(name: "Restore Truth", club: "ARCHIVE CC")

        openLocker()
        logResult(opponent: "Archive Test CC", scoreFor: "6", scoreAgainst: "5", note: "Export recovery result")
        assertLockerShowsResult(opponent: "Archive Test CC", note: "Export recovery result")

        exportClearImportFromSettings()
        openRoster()
        assertRosterShowsCurler(name: "Restore Truth", club: "ARCHIVE CC")
        openLocker()
        assertLockerShowsResult(opponent: "Archive Test CC", note: "Export recovery result")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openRoster()
        assertRosterShowsCurler(name: "Restore Truth", club: "ARCHIVE CC")
        openLocker()
        assertLockerShowsResult(opponent: "Archive Test CC", note: "Export recovery result")
    }

    func testSetupImportAndReturnToSetupRecoveryLoopSurvivesRelaunch() throws {
        startBlankSeason(name: "Setup Import User", homeClub: "Setup Curling Club", province: "AB")

        openRoster()
        addRosterCurler(name: "Setup Restore", club: "Setup CC", province: "AB")
        assertRosterShowsCurler(name: "Setup Restore", club: "SETUP CC")

        openSettings()
        tapWhenReady(app.buttons["curlplan.settings.export-season"])
        XCTAssertTrue(app.staticTexts["Season export copied."].waitForExistence(timeout: 4))
        tapWhenReady(app.buttons["curlplan.settings.show-setup"])
        app.buttons["curlplan.settings.confirm.setup"].firstMatch.tap()
        if app.buttons["curlplan.settings.done"].waitForExistence(timeout: 2) {
            app.buttons["curlplan.settings.done"].tap()
        }

        XCTAssertTrue(app.buttons["curlplan.setup.import-saved-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.import-saved-season"].tap()
        XCTAssertTrue(app.textViews["curlplan.import.json"].waitForExistence(timeout: 4))
        tapWhenReady(app.buttons["curlplan.import.paste"])
        tapWhenReady(app.buttons["curlplan.import.confirm"])
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openRoster()
        assertRosterShowsCurler(name: "Setup Restore", club: "SETUP CC")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openRoster()
        assertRosterShowsCurler(name: "Setup Restore", club: "SETUP CC")
    }

    func testFailedImportPreservesCurrentSeasonInSettingsAcrossRelaunch() throws {
        startBlankSeason(name: "Failed Import User", homeClub: "Guard Curling Club", province: "SK")

        openRoster()
        addRosterCurler(name: "Bad Import Guard", club: "Guard CC", province: "SK")
        assertRosterShowsCurler(name: "Bad Import Guard", club: "GUARD CC")

        openSettings()
        tapWhenReady(app.buttons["curlplan.settings.import-season"])
        let editor = app.textViews["curlplan.import.json"]
        XCTAssertTrue(editor.waitForExistence(timeout: 4))
        editor.tap()
        editor.typeText("{not valid json")
        tapWhenReady(app.buttons["curlplan.import.confirm"])
        XCTAssertTrue(app.staticTexts["That does not look like a CurlPlan season export."].waitForExistence(timeout: 4))
        app.buttons["curlplan.import.cancel"].tap()
        app.buttons["curlplan.settings.done"].tap()

        openRoster()
        assertRosterShowsCurler(name: "Bad Import Guard", club: "GUARD CC")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        openRoster()
        assertRosterShowsCurler(name: "Bad Import Guard", club: "GUARD CC")
    }

    func testDiscoverSaveActionPersistsToLocalRosterState() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openLocker()
        tapButton("curlplan.locker.tab.discover")
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 4))
        app.buttons["curlplan.discover.follow.sam"].tap()
        assertSamSavedInRoster()

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        assertSamSavedInRoster()
    }

    func testRouteDistanceAndLocalRosterSurfacesStayTruthfulAcrossRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openPassport()
        assertPassportStat("curlplan.passport.distance", contains: "KM")
        XCTAssertFalse(app.descendants(matching: .any)["curlplan.passport.distance"].label.contains("— KM"))

        openRoster()
        searchRoster("Sam Reid")
        tapButton("curlplan.roster.follow.sam")
        assertButton("curlplan.roster.follow.sam", contains: "Saved")
        tapButton("curlplan.roster.curler.sam")
        assertButton("curlplan.profile.toggleFollow", contains: "Saved")
        tapButton("curlplan.profile.toggleFollow")
        assertButton("curlplan.profile.toggleFollow", contains: "Save local")
        tapButton("curlplan.profile.toggleFollow")
        assertButton("curlplan.profile.toggleFollow", contains: "Saved")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        assertSamSavedInRoster()
    }

    func testLockerFeedSearchFilterAndBackingSourceDeletionSurvivesRelaunch() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openLocker()
        logResult(opponent: "Filter Proof CC",
                  scoreFor: "8",
                  scoreAgainst: "3",
                  note: "Search filter proof result")
        searchLockerFeed("Filter Proof")
        assertLockerShowsResult(opponent: "Filter Proof CC", note: "Search filter proof result")

        let delete = app.buttons["curlplan.result.delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 4))
        delete.tap()
        XCTAssertTrue(app.staticTexts["Result deleted."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["No posts found"].waitForExistence(timeout: 4))

        tapButton("curlplan.locker.tab.discover")
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 4))
        tapButton("curlplan.discover.follow.sam")
        assertSamSavedInRoster()

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
        assertSamSavedInRoster()
    }

    func testSmallScreenAccessibilityPrimaryControlsRemainReachable() throws {
        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        openLocker()
        tapButton("curlplan.locker.search")
        XCTAssertTrue(app.textFields["curlplan.locker.searchField"].waitForExistence(timeout: 4))
        tapButton("curlplan.logResult")
        XCTAssertTrue(app.staticTexts["Log a result"].waitForExistence(timeout: 4))
        tapButton("curlplan.sheet.cancel")

        openRoster()
        tapButton("curlplan.roster.search")
        XCTAssertTrue(app.textFields["curlplan.roster.searchField"].waitForExistence(timeout: 4))
        tapButton("curlplan.addCurler")
        XCTAssertTrue(app.staticTexts["Add to roster"].waitForExistence(timeout: 4))
        tapButton("curlplan.sheet.cancel")

        openBrierPatchDetails()
        tapButton("curlplan.bonspiel.roster.add.team-mercer")
        XCTAssertTrue(app.staticTexts["Team member"].waitForExistence(timeout: 4))
        tapButton("curlplan.sheet.cancel")
        assertBonspielGameStatus(gameID: "bp-g1", contains: "Lineup locked")
        app.buttons["Done"].tap()

        openSettings()
        XCTAssertTrue(app.buttons["curlplan.settings.export-season"].waitForExistence(timeout: 4))
        app.buttons["curlplan.settings.done"].tap()
    }

    // AS 01/02/03 in-app proof: create a backend account (imports the local season),
    // sign out, sign back in (restores the season), then delete the account.
    // Opt-in: set CURLPLAN_RUN_ACCOUNT_UI=1 in the test runner environment AND ensure
    // the deployed backend is reachable. Cleartext http to the tailnet IP requires an
    // ATS exception or TLS, so this is skipped by default to keep the suite green.
    func testAccountCredentialScreenflowCreateSignInDeleteAgainstBackend() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CURLPLAN_RUN_ACCOUNT_UI"] == "1",
                          "Set CURLPLAN_RUN_ACCOUNT_UI=1 and ensure the deployed account backend is reachable (ATS exception or TLS).")

        XCTAssertTrue(app.buttons["curlplan.setup.use-demo-season"].waitForExistence(timeout: 6))
        app.buttons["curlplan.setup.use-demo-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))

        let stamp = Int(Date().timeIntervalSince1970)
        let handle = "uitest-\(stamp)"
        let password = "uitest-pass-\(stamp)"
        let message = app.staticTexts["curlplan.settings.account.message"]

        openSettings()

        // Create account + import the local demo season.
        tapButton("curlplan.settings.create-backend-account")
        fillCredential(handle: handle, password: password)
        expectLabelContains(message, "imported season version", timeout: 30)

        // Sign out revokes the server session.
        tapButton("curlplan.settings.sign-out-account")
        expectLabelContains(message, "signed out", timeout: 25)

        // Sign back in with the same credentials restores the account season.
        tapButton("curlplan.settings.sign-in-to-account")
        fillCredential(handle: handle, password: password)
        expectLabelContains(message, "season version", timeout: 30)

        // Clean up: delete the throwaway backend account.
        tapButton("curlplan.settings.delete-backend-account")
        let confirm = app.buttons["curlplan.settings.confirm.deleteAccount"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 6))
        confirm.tap()
        expectLabelContains(message, "deleted", timeout: 30)
    }

    private func fillCredential(handle: String, password: String) {
        let handleField = app.textFields["curlplan.account.credential.handle"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 6))
        handleField.tap()
        handleField.typeText(handle)
        let passwordField = app.secureTextFields["curlplan.account.credential.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 4))
        passwordField.tap()
        passwordField.typeText(password)
        let submit = app.buttons["curlplan.account.credential.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 4))
        submit.tap()
    }

    private func expectLabelContains(_ element: XCUIElement, _ text: String, timeout: TimeInterval) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    private func openLocker() {
        openTab(identifier: "locker", title: "Locker", expectedHeading: "Locker Room")
    }

    private func openPassport() {
        openTab(identifier: "passport", title: "Passport", expectedHeading: "CurlPlan")
    }

    private func openRoster() {
        openTab(identifier: "roster", title: "Roster", expectedHeading: "Roster")
    }

    private func assertSamSavedInRoster() {
        openRoster()
        searchRoster("Sam Reid")
        assertButton("curlplan.roster.follow.sam", contains: "Saved")
    }

    private func openSettings() {
        let settings = app.buttons["curlplan.settings"]
        if !settings.waitForExistence(timeout: 2) {
            openTab(identifier: "passport", title: "Passport", expectedHeading: "CurlPlan")
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.tap()
        XCTAssertTrue(app.buttons["curlplan.settings.done"].waitForExistence(timeout: 4))
    }

    private func openSpiels() {
        openTab(identifier: "spiels", title: "Spiels", expectedHeading: "Spiels")
    }

    private func openBrierPatchDetails() {
        openSpiels()
        let details = app.buttons["curlplan.spiel.details.sp1"]
        for _ in 0..<4 where !details.exists || !details.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(details.waitForExistence(timeout: 4))
        details.tap()
        XCTAssertTrue(app.staticTexts["Brier Patch Open"].waitForExistence(timeout: 4))
    }

    private func openStopFromPassport(_ id: String) {
        openPassport()
        let stop = app.buttons["curlplan.recentStop.\(id)"]
        for _ in 0..<4 where !stop.exists {
            app.swipeUp()
        }
        XCTAssertTrue(stop.waitForExistence(timeout: 4))
        stop.tap()
        let hasStart = app.buttons["curlplan.stop.startVisit"].waitForExistence(timeout: 2)
        let hasEnd = app.buttons["curlplan.stop.endVisit"].waitForExistence(timeout: 2)
        XCTAssertTrue(hasStart || hasEnd)
    }

    private func tapButton(_ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<6 where !button.exists || !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        button.tap()
    }

    private func openTab(identifier: String, title: String, expectedHeading: String) {
        let button = app.buttons["curlplan.tab.\(identifier)"]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        } else if app.buttons["curlplan.tab.label.\(identifier)"].waitForExistence(timeout: 4) {
            app.buttons["curlplan.tab.label.\(identifier)"].tap()
        } else if app.buttons[title].waitForExistence(timeout: 4) {
            app.buttons[title].tap()
        } else {
            let label = app.staticTexts["curlplan.tab.label.\(identifier)"]
            XCTAssertTrue(label.waitForExistence(timeout: 4))
            label.tap()
        }
        XCTAssertTrue(app.staticTexts[expectedHeading].waitForExistence(timeout: 4))
    }

    private func toggleAttendanceTwice() {
        let going = app.buttons["Going ✓"].firstMatch
        if !going.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(going.waitForExistence(timeout: 4))
        going.tap()

        let imIn = app.buttons["I'm in"].firstMatch
        XCTAssertTrue(imIn.waitForExistence(timeout: 4))
        imIn.tap()
        XCTAssertTrue(app.buttons["Going ✓"].firstMatch.waitForExistence(timeout: 4))
    }

    private func logResult(opponent: String,
                           scoreFor: String,
                           scoreAgainst: String,
                           note: String,
                           stopID: String? = nil,
                           curlerID: String? = nil) {
        let logResult = app.buttons["curlplan.logResult"]
        XCTAssertTrue(logResult.waitForExistence(timeout: 4))
        logResult.tap()

        let opponentField = app.textFields["curlplan.field.opponent"]
        XCTAssertTrue(opponentField.waitForExistence(timeout: 4))
        opponentField.tap()
        opponentField.typeText(opponent)

        let forField = app.textFields["curlplan.field.your-score"]
        XCTAssertTrue(forField.waitForExistence(timeout: 4))
        forField.tap()
        forField.typeText(scoreFor)

        let againstField = app.textFields["curlplan.field.their-score"]
        XCTAssertTrue(againstField.waitForExistence(timeout: 4))
        againstField.tap()
        againstField.typeText(scoreAgainst)

        app.staticTexts["Log a result"].tap()
        if let stopID {
            tapSheetButton("curlplan.result.stop.\(stopID)")
        }
        if let curlerID {
            tapSheetButton("curlplan.result.curler.\(curlerID)")
        }

        let noteField = app.textFields["curlplan.field.note"]
        if !noteField.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(noteField.waitForExistence(timeout: 4))
        noteField.tap()
        noteField.typeText(note)

        app.staticTexts["Log a result"].tap()
        let save = app.buttons["curlplan.sheet.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        save.tap()
        XCTAssertTrue(app.staticTexts["Result recorded."].waitForExistence(timeout: 4))
    }

    private func editFirstResult(opponent: String, scoreFor: String, scoreAgainst: String, note: String) {
        let edit = app.buttons["curlplan.result.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 4))
        edit.tap()

        XCTAssertTrue(app.staticTexts["Edit result"].waitForExistence(timeout: 4))
        replaceText(app.textFields["curlplan.field.opponent"], with: opponent)
        replaceText(app.textFields["curlplan.field.your-score"], with: scoreFor)
        replaceText(app.textFields["curlplan.field.their-score"], with: scoreAgainst)
        replaceText(app.textFields["curlplan.field.note"], with: note)

        app.staticTexts["Edit result"].tap()
        app.buttons["curlplan.sheet.save"].tap()
        XCTAssertTrue(app.staticTexts["Result updated."].waitForExistence(timeout: 4))
    }

    private func deleteAndUndoFirstResult(note: String) {
        let delete = app.buttons["curlplan.result.delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 4))
        delete.tap()
        XCTAssertTrue(app.staticTexts["Result deleted."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[note].waitForNonExistence(timeout: 4))

        let undo = app.buttons["curlplan.action.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 4))
        undo.tap()
        XCTAssertTrue(app.staticTexts["Undo complete."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 4))
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 80))
        field.typeText(text)
    }

    private func assertLockerShowsResult(opponent: String, note: String) {
        let opponentText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", opponent)).firstMatch
        if !opponentText.waitForExistence(timeout: 3) {
            app.swipeDown()
        }
        XCTAssertTrue(opponentText.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["LOCAL RESULT"].firstMatch.waitForExistence(timeout: 4))
    }

    private func searchLockerFeed(_ text: String) {
        let field = app.textFields["curlplan.locker.searchField"]
        if !field.waitForExistence(timeout: 1) {
            let search = app.buttons["curlplan.locker.search"]
            XCTAssertTrue(search.waitForExistence(timeout: 4))
            search.tap()
        }
        replaceText(app.textFields["curlplan.locker.searchField"], with: text)
    }

    private func searchRoster(_ text: String) {
        let field = app.textFields["curlplan.roster.searchField"]
        if !field.waitForExistence(timeout: 1) {
            let search = app.buttons["curlplan.roster.search"]
            XCTAssertTrue(search.waitForExistence(timeout: 4))
            search.tap()
        }
        replaceText(app.textFields["curlplan.roster.searchField"], with: text)
    }

    private func assertPassportStat(_ identifier: String, contains expected: String) {
        let stat = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(stat.waitForExistence(timeout: 4))
        XCTAssertTrue(stat.label.contains(expected), "Expected \(identifier) to contain \(expected), got \(stat.label)")
    }

    private func assertButton(_ identifier: String, contains expected: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        XCTAssertTrue(button.label.contains(expected), "Expected \(identifier) to contain \(expected), got \(button.label)")
    }

    private func assertStopShowsLinkedResult(opponent: String, score: String) {
        let opponentText = app.staticTexts["vs \(opponent)"]
        for _ in 0..<5 where !opponentText.exists {
            app.swipeUp()
        }
        XCTAssertTrue(opponentText.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[score].waitForExistence(timeout: 4))
    }

    private func assertStopShowsCurler(name: String, id: String) {
        let row = app.buttons["curlplan.stop.curler.\(id)"]
        for _ in 0..<6 where !row.exists {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 4))
    }

    private func openCurlerFromCurrentStop(id: String, name: String) {
        let row = app.buttons["curlplan.stop.curler.\(id)"]
        for _ in 0..<6 where !row.exists || !row.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 4))
        row.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 4))
    }

    private func assertProfileShowsLinkedResult(score: String, context: String) {
        let scoreText = app.staticTexts[score]
        for _ in 0..<6 where !scoreText.exists {
            app.swipeUp()
        }
        XCTAssertTrue(scoreText.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[context].waitForExistence(timeout: 4))
    }

    private func assertProfileShowsSharedRink(_ rink: String) {
        let rinkText = app.staticTexts[rink]
        for _ in 0..<6 where !rinkText.exists {
            app.swipeUp()
        }
        XCTAssertTrue(rinkText.waitForExistence(timeout: 4))
    }

    private func assertBonspielGameStatus(gameID: String, contains expected: String) {
        let status = app.staticTexts["curlplan.bonspiel.\(gameID).status"]
        for _ in 0..<8 where !status.exists {
            app.swipeUp()
        }
        XCTAssertTrue(status.waitForExistence(timeout: 4))
        XCTAssertTrue(status.label.contains(expected), "Expected \(gameID) status to contain \(expected), got \(status.label)")
    }

    private func assertBonspielGameScore(gameID: String, contains expected: String) {
        let score = app.staticTexts["curlplan.bonspiel.\(gameID).score"]
        for _ in 0..<8 where !score.exists {
            app.swipeUp()
        }
        XCTAssertTrue(score.waitForExistence(timeout: 4))
        XCTAssertTrue(score.label.contains(expected), "Expected \(gameID) score to contain \(expected), got \(score.label)")
    }

    private func assertBonspielGameMessage(contains expected: String) {
        let message = app.staticTexts["curlplan.bonspiel.games.message"]
        for _ in 0..<6 where !message.exists {
            app.swipeUp()
        }
        XCTAssertTrue(message.waitForExistence(timeout: 4))
        XCTAssertTrue(message.label.contains(expected), "Expected bonspiel game message to contain \(expected), got \(message.label)")
    }

    private func assertProfileShareText(name: String, club: String) {
        let shareText = app.staticTexts["curlplan.profile.shareText"]
        for _ in 0..<5 where !shareText.exists {
            app.swipeUp()
        }
        XCTAssertTrue(shareText.waitForExistence(timeout: 4))
        XCTAssertTrue(shareText.label.contains(name), "Expected copied profile card to contain \(name), got \(shareText.label)")
        XCTAssertTrue(shareText.label.contains(club), "Expected copied profile card to contain \(club), got \(shareText.label)")
        XCTAssertTrue(shareText.label.contains("Record"), "Expected copied profile card to include record, got \(shareText.label)")
        XCTAssertTrue(shareText.label.contains("win"), "Expected copied profile card to include win rate, got \(shareText.label)")
    }

    private func confirmProfileDelete() {
        let confirmByID = app.buttons["curlplan.profile.confirmDelete"].firstMatch
        if confirmByID.waitForExistence(timeout: 2) {
            confirmByID.tap()
            return
        }
        let confirmByLabel = app.buttons["Remove curler"].firstMatch
        XCTAssertTrue(confirmByLabel.waitForExistence(timeout: 4))
        confirmByLabel.tap()
    }

    private func assertStopDoesNotShowCurler(id: String, name: String) {
        let row = app.buttons["curlplan.stop.curler.\(id)"]
        XCTAssertFalse(row.waitForExistence(timeout: 2), "Expected \(name) to be removed from this stop.")
    }

    private func assertRosterSearchDoesNotFindCurler(id: String, name: String) {
        let field = app.textFields["curlplan.roster.searchField"]
        if !field.waitForExistence(timeout: 1) {
            let search = app.buttons["curlplan.roster.search"]
            XCTAssertTrue(search.waitForExistence(timeout: 4))
            search.tap()
        }
        replaceText(app.textFields["curlplan.roster.searchField"], with: name)
        XCTAssertFalse(app.buttons["curlplan.roster.curler.\(id)"].waitForExistence(timeout: 2), "Expected \(name) to be removed from roster search.")
        XCTAssertTrue(app.staticTexts["No curlers found"].waitForExistence(timeout: 4))
    }

    private func assertRosterShowsCurler() {
        XCTAssertTrue(app.staticTexts["Ivy Truth"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["SKIP · PROOF CC"].waitForExistence(timeout: 4))
    }

    private func startBlankSeason(name: String, homeClub: String, province: String) {
        XCTAssertTrue(app.buttons["curlplan.setup.start-blank-season"].waitForExistence(timeout: 6))
        app.textFields["curlplan.field.your-name"].tap()
        app.textFields["curlplan.field.your-name"].typeText(name)
        app.textFields["curlplan.field.home-rink"].tap()
        app.textFields["curlplan.field.home-rink"].typeText(homeClub)
        app.textFields["curlplan.field.province"].tap()
        app.textFields["curlplan.field.province"].typeText(province)
        app.buttons["curlplan.setup.start-blank-season"].tap()
        XCTAssertTrue(app.otherElements["curlplan.main"].waitForExistence(timeout: 6))
    }

    private func addRosterCurler(name: String, club: String, province: String) {
        let addCurler = app.buttons["curlplan.addCurler"]
        XCTAssertTrue(addCurler.waitForExistence(timeout: 4))
        addCurler.tap()

        let nameField = app.textFields["curlplan.field.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 4))
        nameField.tap()
        nameField.typeText(name)
        app.textFields["curlplan.field.club"].tap()
        app.textFields["curlplan.field.club"].typeText(club)
        app.textFields["curlplan.field.province"].tap()
        app.textFields["curlplan.field.province"].typeText(province)
        app.staticTexts["Add to roster"].tap()
        app.buttons["curlplan.sheet.save"].tap()
    }

    private func assertRosterShowsCurler(name: String, club: String) {
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["SKIP · \(club)"].waitForExistence(timeout: 4))
    }

    private func exportClearImportFromSettings() {
        openSettings()
        tapWhenReady(app.buttons["curlplan.settings.export-season"])
        XCTAssertTrue(app.staticTexts["Season export copied."].waitForExistence(timeout: 4))
        tapWhenReady(app.buttons["curlplan.settings.clear-season"])
        app.buttons["curlplan.settings.confirm.clearSeason"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Season cleared."].waitForExistence(timeout: 4))
        tapWhenReady(app.buttons["curlplan.settings.import-season"])
        XCTAssertTrue(app.textViews["curlplan.import.json"].waitForExistence(timeout: 4))
        tapWhenReady(app.buttons["curlplan.import.confirm"])
        XCTAssertTrue(app.staticTexts["Season imported."].waitForExistence(timeout: 4))
        app.buttons["curlplan.settings.done"].tap()
    }

    private func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 6) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    private func tapSheetButton(_ identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<5 where !button.exists || !button.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        XCTAssertTrue(button.isHittable)
        button.tap()
    }
}
