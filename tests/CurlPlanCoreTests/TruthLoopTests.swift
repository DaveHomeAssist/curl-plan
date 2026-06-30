import XCTest
@testable import CurlPlanCore

final class StoreMutationTests: XCTestCase {
    func testEveryWriteReturnsReceiptAndChangesExpectedDomains() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        let before = store.results.count

        let receipt = store.addResult(body: "Controlled draw finish",
                                      scoreFor: 8,
                                      scoreAgainst: 6,
                                      vs: "Northern",
                                      stopID: "kelowna")

        XCTAssertEqual(receipt.action, "addResult")
        XCTAssertTrue(receipt.changedDomains.contains(.results))
        XCTAssertTrue(receipt.changedDomains.contains(.feed))
        XCTAssertNotNil(receipt.undoToken)
        XCTAssertEqual(store.results.count, before + 1)
    }

    func testAddSpielCreatesCanonicalDatesBonspielAndKnownRouteStop() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.startBlankSeason(name: "Alex Stone", homeClub: "Test CC", province: "BC")

        let receipt = store.addSpiel(name: "Okanagan Classic",
                                     whereText: "Kelowna, BC",
                                     startDate: testDate(year: 2026, month: 3, day: 6),
                                     endDate: testDate(year: 2026, month: 3, day: 8),
                                     status: "You're in",
                                     discipline: .mixed)

        XCTAssertTrue(receipt.changedDomains.contains(.spiels))
        XCTAssertTrue(receipt.changedDomains.contains(.bonspiels))
        XCTAssertTrue(receipt.changedDomains.contains(.stops))

        let spiel = store.spiels[0]
        XCTAssertEqual(spiel.startDate, "2026-03-06")
        XCTAssertEqual(spiel.endDate, "2026-03-08")
        XCTAssertEqual(spiel.whenText, "MAR 6-8")
        XCTAssertNotNil(spiel.stopID)
        XCTAssertEqual(spiel.venueID, "venue-kelowna-curling-club")

        let stop = spiel.stopID.flatMap(store.stop)
        XCTAssertEqual(stop?.name, "Okanagan Classic")
        XCTAssertEqual(stop?.club, "Kelowna Curling Club")
        XCTAssertEqual(stop?.latitude, 49.8880)
        XCTAssertEqual(stop?.longitude, -119.4960)
        XCTAssertEqual(stop?.venueID, "venue-kelowna-curling-club")

        let bonspiel = store.bonspiel(for: spiel.id)
        XCTAssertEqual(bonspiel?.startDate, "2026-03-06")
        XCTAssertEqual(bonspiel?.endDate, "2026-03-08")
        XCTAssertEqual(bonspiel?.venueID, "venue-kelowna-curling-club")
        XCTAssertEqual(bonspiel?.venue.name, "Kelowna Curling Club")
        XCTAssertEqual(bonspiel?.venue.city, "Kelowna")
        XCTAssertEqual(bonspiel?.venue.region, "BC")
        XCTAssertEqual(bonspiel?.timezone, "America/Vancouver")
    }

    func testAddSpielDoesNotInventRouteStopForUnknownVenue() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.startBlankSeason(name: "Alex Stone", homeClub: "Test CC", province: "BC")
        let startingVenueCount = store.venues.count

        let receipt = store.addSpiel(name: "Mystery Spiel",
                                     whereText: "Some Arena, SK",
                                     startDate: testDate(year: 2026, month: 4, day: 10),
                                     endDate: testDate(year: 2026, month: 4, day: 12),
                                     status: "Watching",
                                     discipline: .fourPlayer)

        XCTAssertFalse(receipt.changedDomains.contains(.stops))
        XCTAssertFalse(receipt.changedDomains.contains(.venues))
        XCTAssertEqual(store.stops.count, 0)
        XCTAssertEqual(store.venues.count, startingVenueCount)
        XCTAssertNil(store.spiels[0].stopID)
        XCTAssertNil(store.spiels[0].venueID)
        XCTAssertEqual(store.bonspiel(for: store.spiels[0].id)?.venue.city, "Some Arena")
        XCTAssertEqual(store.bonspiel(for: store.spiels[0].id)?.venue.region, "SK")
    }

    func testAddSpielStoresSelectedVenueAndCreatesCoordinateRouteStop() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.startBlankSeason(name: "Alex Stone", homeClub: "Test CC", province: "BC")
        let selectedVenue = Venue(id: "venue-geocoded-prairie-ice-centre",
                                  displayName: "Prairie Ice Centre",
                                  aliases: ["Prairie Ice Centre, Saskatoon"],
                                  clubName: "Prairie Ice Centre",
                                  city: "Saskatoon",
                                  region: "SK",
                                  country: "CA",
                                  postalAddress: "Saskatoon, SK",
                                  latitude: 52.1579,
                                  longitude: -106.6702,
                                  timezone: "America/Regina",
                                  authority: .geocodedAddress)

        let receipt = store.addSpiel(name: "Prairie Spiel",
                                     whereText: "Prairie Ice Centre",
                                     startDate: testDate(year: 2026, month: 4, day: 17),
                                     endDate: testDate(year: 2026, month: 4, day: 19),
                                     status: "You're in",
                                     discipline: .fourPlayer,
                                     venue: selectedVenue)

        XCTAssertTrue(receipt.changedDomains.contains(.venues))
        XCTAssertTrue(receipt.changedDomains.contains(.stops))
        XCTAssertEqual(store.venues.first?.id, selectedVenue.id)
        XCTAssertEqual(store.spiels[0].venueID, selectedVenue.id)

        let stop = store.spiels[0].stopID.flatMap(store.stop)
        XCTAssertEqual(stop?.venueID, selectedVenue.id)
        XCTAssertEqual(stop?.latitude, 52.1579)
        XCTAssertEqual(stop?.longitude, -106.6702)

        let bonspiel = store.bonspiel(for: store.spiels[0].id)
        XCTAssertEqual(bonspiel?.venueID, selectedVenue.id)
        XCTAssertEqual(bonspiel?.venue.name, "Prairie Ice Centre")
        XCTAssertEqual(bonspiel?.timezone, "America/Regina")
    }

    private func testDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}

final class DerivedSummaryTests: XCTestCase {
    func testPassportSummaryGamesDeriveFromResultsAndImportedCount() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)

        XCTAssertEqual(store.seasonSummary.games, store.results.count + store.profile.importedGameCount)
    }

    func testRouteDistanceIsUnavailableWhenNoMeasuredDistanceExists() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)

        XCTAssertEqual(store.seasonSummary.distanceLabel, "—")
    }
}

final class ResultLoopTests: XCTestCase {
    func testCreateDeleteAndUndoResultUpdatesDerivedStats() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        let startGames = store.seasonSummary.games
        let createReceipt = store.addResult(body: "A tidy win",
                                            scoreFor: 9,
                                            scoreAgainst: 4,
                                            vs: "Granite",
                                            stopID: "kelowna")

        XCTAssertEqual(store.seasonSummary.games, startGames + 1)
        let id = store.results[0].id
        store.deleteResult(id)
        XCTAssertEqual(store.seasonSummary.games, startGames)

        let undoToken = createReceipt.undoToken!
        _ = store.undo(undoToken)
        XCTAssertEqual(store.seasonSummary.games, startGames)
    }

    func testUpdateResultChangesDerivedOutcome() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        let startWins = store.seasonSummary.wins
        store.addResult(body: "Started as a win",
                        scoreFor: 8,
                        scoreAgainst: 4,
                        vs: "Granite",
                        stopID: "kelowna")
        let id = store.results[0].id

        XCTAssertEqual(store.seasonSummary.wins, startWins + 1)

        store.updateResult(id: id, body: "Corrected score", scoreFor: 3, scoreAgainst: 6, vs: "Granite")

        XCTAssertEqual(store.results[0].res, "LOSS")
        XCTAssertEqual(store.seasonSummary.wins, startWins)
    }
}

final class VisitLoopTests: XCTestCase {
    func testStartAndEndVisitDriveCurrentStopSelector() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)

        let receipt = store.startVisit(stopID: "kelowna", curlerIDs: ["sam"], note: "Practice ice")
        XCTAssertTrue(receipt.changedDomains.contains(.visits))
        XCTAssertTrue(store.isCurrentStop("kelowna"))
        XCTAssertFalse(store.isCurrentStop("kamloops"))

        store.endVisit(stopID: "kelowna")
        XCTAssertFalse(store.isCurrentStop("kelowna"))
        XCTAssertTrue(store.peopleMetIDs(for: "kelowna").contains("sam"))
    }
}

final class RosterLineupTests: XCTestCase {
    func testAttendanceDeduplicatesByCurlerPerSpiel() {
        var data = Seed.appData(setupComplete: true)
        data.attendance.append(SpielAttendance(spielID: "sp1", curlerID: "sam", status: .going, updatedAt: "duplicate"))
        let store = Store(appData: data, loadPersisted: false)

        let samCount = store.attendeeIDs(for: "sp1").filter { $0 == "sam" }.count
        XCTAssertEqual(samCount, 1)
    }

    func testLineupSubmitAndLockBlocksLateEdits() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .readyForLineup
        data.bonspiels[0].games[0].scheduledStartAt = "2099-02-14 10:00"
        let store = Store(appData: data, loadPersisted: false)

        let slots = [
            BonspielLineupSlot(memberID: "tm-sam", position: "Lead", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-dee", position: "Second", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-jo", position: "Third", isSkip: false, isViceSkip: true),
            BonspielLineupSlot(memberID: "tm-dana", position: "Fourth", isSkip: true, isViceSkip: false)
        ]

        let submit = store.submitBonspielLineup(bonspielID: "bon-brier-patch-open",
                                                gameID: "bp-g1",
                                                teamID: "team-mercer",
                                                slots: slots,
                                                submittedAt: "test")
        XCTAssertTrue(submit.changedDomains.contains(.bonspiels))
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.gameLineups.first(where: { $0.teamID == "team-mercer" })?.submittedAt, "test")

        let lock = store.lockBonspielLineup(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")
        XCTAssertTrue(lock.changedDomains.contains(.bonspiels))
        XCTAssertTrue(store.lineupIsLocked(bonspielID: "bon-brier-patch-open", gameID: "bp-g1"))

        let blocked = store.submitBonspielLineup(bonspielID: "bon-brier-patch-open",
                                                 gameID: "bp-g1",
                                                 teamID: "team-mercer",
                                                 slots: Array(slots.reversed()),
                                                 submittedAt: "late")
        XCTAssertEqual(blocked.changedDomains, [])
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.gameLineups.first(where: { $0.teamID == "team-mercer" })?.submittedAt, "test")
    }

    func testInvalidLineupCountIsRejected() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .readyForLineup
        data.bonspiels[0].games[0].scheduledStartAt = "2099-02-14 10:00"
        let store = Store(appData: data, loadPersisted: false)
        let shortLineup = [
            BonspielLineupSlot(memberID: "tm-sam", position: "Lead", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-dee", position: "Second", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-jo", position: "Third", isSkip: true, isViceSkip: true)
        ]

        let receipt = store.submitBonspielLineup(bonspielID: "bon-brier-patch-open",
                                                 gameID: "bp-g1",
                                                 teamID: "team-mercer",
                                                 slots: shortLineup)

        XCTAssertEqual(receipt.changedDomains, [])
        XCTAssertTrue(receipt.userMessage.contains("Lineup needs 4 players"))
    }

    func testLineupLockWindowBlocksLateEdits() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .readyForLineup
        data.bonspiels[0].games[0].scheduledStartAt = "2000-02-14 10:00"
        let store = Store(appData: data, loadPersisted: false)
        let slots = [
            BonspielLineupSlot(memberID: "tm-sam", position: "Lead", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-dee", position: "Second", isSkip: false, isViceSkip: false),
            BonspielLineupSlot(memberID: "tm-jo", position: "Third", isSkip: false, isViceSkip: true),
            BonspielLineupSlot(memberID: "tm-dana", position: "Fourth", isSkip: true, isViceSkip: false)
        ]

        let receipt = store.submitBonspielLineup(bonspielID: "bon-brier-patch-open",
                                                 gameID: "bp-g1",
                                                 teamID: "team-mercer",
                                                 slots: slots)

        XCTAssertEqual(receipt.changedDomains, [])
        XCTAssertTrue(receipt.userMessage.contains("locked"))
        XCTAssertNotEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.gameLineups.first(where: { $0.teamID == "team-mercer" })?.submittedAt, "now")
    }

    func testLockedLineupMemberCannotBeRemovedSilently() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)

        let receipt = store.removeBonspielTeamMember(bonspielID: "bon-brier-patch-open",
                                                     teamID: "team-mercer",
                                                     memberID: "tm-sam")

        XCTAssertEqual(receipt.changedDomains, [])
        XCTAssertTrue(receipt.userMessage.contains("locked"))
        XCTAssertNotNil(store.bonspiel("bon-brier-patch-open")?.teams.first(where: { $0.id == "team-mercer" })?.members.first(where: { $0.id == "tm-sam" }))
    }
}

final class BonspielScoreTests: XCTestCase {
    func testGameScoreLabelDerivesOnlyFromEndScores() {
        let game = Seed.bonspiels[0].games[0]
        let teamATotal = game.ends.map(\.teamA).reduce(0, +)
        let teamBTotal = game.ends.map(\.teamB).reduce(0, +)

        XCTAssertEqual(game.scoreLabel, "\(teamATotal)-\(teamBTotal)")
    }

    func testEndScoreRejectsBothTeamsScoringAndAllowsBlankEnds() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .inProgress
        data.bonspiels[0].games[0].ends = []
        let store = Store(appData: data, loadPersisted: false)

        let invalid = store.recordBonspielEndScore(bonspielID: "bon-brier-patch-open",
                                                   gameID: "bp-g1",
                                                   endNumber: 1,
                                                   teamA: 1,
                                                   teamB: 1)
        XCTAssertEqual(invalid.changedDomains, [])
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.ends.count, 0)

        let blank = store.recordBonspielEndScore(bonspielID: "bon-brier-patch-open",
                                                 gameID: "bp-g1",
                                                 endNumber: 1,
                                                 teamA: 0,
                                                 teamB: 0,
                                                 isBlank: true)
        XCTAssertTrue(blank.changedDomains.contains(.bonspiels))
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.scoreLabel, "0-0")
    }

    func testExtraEndRequiresTiedRegulationAndUpdatesDerivedTotal() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .inProgress
        data.bonspiels[0].games[0].ends = (1...8).map { end in
            BonspielEndScore(id: "e\(end)",
                             endNumber: end,
                             teamA: end.isMultiple(of: 2) ? 1 : 0,
                             teamB: end.isMultiple(of: 2) ? 0 : 1,
                             hammerTeamIDStart: nil,
                             isBlank: false,
                             isExtraEnd: false,
                             measureRequired: false,
                             powerPlayUsed: false)
        }
        let store = Store(appData: data, loadPersisted: false)

        let receipt = store.recordBonspielEndScore(bonspielID: "bon-brier-patch-open",
                                                   gameID: "bp-g1",
                                                   endNumber: 9,
                                                   teamA: 1,
                                                   teamB: 0,
                                                   isExtraEnd: true)

        XCTAssertTrue(receipt.changedDomains.contains(.bonspiels))
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.scoreLabel, "5-4")
    }

    func testConfirmScorecardCreatesOneLinkedLocalResult() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .inProgress
        data.bonspiels[0].games[0].ends = [
            BonspielEndScore(id: "e1", endNumber: 1, teamA: 1, teamB: 0, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
            BonspielEndScore(id: "e2", endNumber: 2, teamA: 0, teamB: 1, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
            BonspielEndScore(id: "e3", endNumber: 3, teamA: 2, teamB: 0, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
            BonspielEndScore(id: "e4", endNumber: 4, teamA: 0, teamB: 0, hammerTeamIDStart: nil, isBlank: true, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
            BonspielEndScore(id: "e5", endNumber: 5, teamA: 1, teamB: 0, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
            BonspielEndScore(id: "e6", endNumber: 6, teamA: 0, teamB: 1, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false)
        ]
        let store = Store(appData: data, loadPersisted: false)

        let receipt = store.confirmBonspielGameResult(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")
        XCTAssertTrue(receipt.changedDomains.contains(.bonspiels))
        XCTAssertTrue(receipt.changedDomains.contains(.results))
        XCTAssertEqual(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.status, .finalized)
        XCTAssertEqual(store.results.filter { $0.bonspielGameID == "bp-g1" }.count, 1)

        _ = store.confirmBonspielGameResult(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")
        XCTAssertEqual(store.results.filter { $0.bonspielGameID == "bp-g1" }.count, 1)
    }

    func testConcededScorecardCanConfirmBeforeMinimumEnds() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].games[0].status = .inProgress
        data.bonspiels[0].games[0].ends = [
            BonspielEndScore(id: "e1", endNumber: 1, teamA: 3, teamB: 0, hammerTeamIDStart: nil, isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false)
        ]
        let store = Store(appData: data, loadPersisted: false)

        _ = store.setBonspielResultFlags(bonspielID: "bon-brier-patch-open", gameID: "bp-g1", conceded: true, forfeited: false)
        let receipt = store.confirmBonspielGameResult(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")

        XCTAssertTrue(receipt.changedDomains.contains(.results))
        XCTAssertEqual(store.results.filter { $0.bonspielGameID == "bp-g1" }.count, 1)
    }
}

final class LockerFeedTests: XCTestCase {
    func testFollowingFeedContainsNoUnfollowedThirdPartyActivity() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)

        for item in store.lockerFollowingFeed {
            if case .result(let post) = item, post.author != "me" {
                XCTAssertTrue(store.curler(post.author)?.following == true)
            }
            if case .review(let post) = item {
                XCTAssertTrue(store.curler(post.author)?.following == true)
            }
        }
    }

    func testAttendanceCountEqualsDeduplicatedCurlerIDsPerSpiel() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        let expected = Set(store.attendance.filter { $0.spielID == "sp1" && $0.status == .going }.map(\.curlerID)).count

        XCTAssertEqual(store.attendanceCount(for: "sp1"), expected)
    }

    func testDiscoverSuggestionCanBeActedOnThroughCircleState() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        XCTAssertTrue(store.discoverSuggestions.contains(where: { $0.id == "sam" }))

        store.toggleFollow("sam")

        XCTAssertFalse(store.discoverSuggestions.contains(where: { $0.id == "sam" }))
    }

    func testLockerSpielAttendanceToggleWritesAttendance() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.setAttendance(spielID: "sp1", curlerID: "me", isGoing: false)
        XCTAssertFalse(store.isAttendingSpiel("sp1"))

        let receipt = store.toggleAttendance(forSpielNamed: "Brier Patch Open")

        XCTAssertTrue(receipt.changedDomains.contains(.attendance))
        XCTAssertTrue(store.isAttendingSpiel("sp1"))
    }
}

final class ProfileHistoryTests: XCTestCase {
    func testSharedVisitFeedsPeopleMetSelector() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.startVisit(stopID: "calgary", curlerIDs: ["carter"], note: "Shared practice")

        XCTAssertTrue(store.peopleMetIDs(for: "calgary").contains("carter"))
    }

    func testImportedSharedRinksAndCountsStayConsistentWhenNoDerivedHistoryExists() {
        var data = Seed.appData(setupComplete: true)
        data.visits = []
        data.results = []
        data.spiels = []
        data.attendance = []
        data.bonspiels = []
        data.stops = data.stops.map { stop in
            var copy = stop
            copy.met = []
            copy.games = []
            copy.record = "—"
            return copy
        }
        let store = Store(appData: data, loadPersisted: false)

        let profile = store.curlerProfile("sam")

        XCTAssertEqual(profile?.sharedRinks.count, 3)
        XCTAssertEqual(profile?.rinks, 9)
        XCTAssertEqual(profile?.mutual, 3)
    }
}

final class PersistenceRoundTripTests: XCTestCase {
    func testExportedAppDataRoundTripsFullCanonicalDomains() throws {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.addResult(body: "Round trip result", scoreFor: 6, scoreAgainst: 3, vs: "Test")
        let encoded = try JSONEncoder().encode(store.appData)
        let decoded = try JSONDecoder().decode(AppData.self, from: encoded)

        XCTAssertEqual(decoded.results.count, store.results.count)
        XCTAssertEqual(decoded.visits.count, store.visits.count)
        XCTAssertEqual(decoded.attendance.count, store.attendance.count)
        XCTAssertEqual(decoded.venues.count, store.venues.count)
        XCTAssertEqual(decoded.bonspiels.count, store.bonspiels.count)
    }

    func testImportReturnsReceiptAndFailedImportPreservesCurrentSeason() throws {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        let before = store.appData
        let receipt = try store.importJSON(store.exportJSON())

        XCTAssertEqual(receipt.action, "importData")
        XCTAssertTrue(receipt.changedDomains.contains(.results))
        XCTAssertEqual(store.appData.results.count, before.results.count)

        XCTAssertThrowsError(try store.importJSON("{not valid json"))
        XCTAssertEqual(store.appData, before)
    }

    func testCleanInstallPrimaryLoopsPersistAndReload() {
        UserDefaults.standard.removeObject(forKey: Persist.appDataKey)
        UserDefaults.standard.removeObject(forKey: Persist.curlersKey)
        UserDefaults.standard.removeObject(forKey: Persist.spielsKey)
        UserDefaults.standard.removeObject(forKey: Persist.feedKey)
        defer {
            UserDefaults.standard.removeObject(forKey: Persist.appDataKey)
            UserDefaults.standard.removeObject(forKey: Persist.curlersKey)
            UserDefaults.standard.removeObject(forKey: Persist.spielsKey)
            UserDefaults.standard.removeObject(forKey: Persist.feedKey)
        }

        let clean = Store(loadPersisted: true)
        XCTAssertFalse(clean.setupComplete)

        clean.startDemoSeason()
        clean.addResult(body: "Clean install loop result",
                        scoreFor: 6,
                        scoreAgainst: 4,
                        vs: "Reload Test",
                        stopID: "kelowna",
                        participantCurlerIDs: ["jo"])
        clean.startVisit(stopID: "calgary", curlerIDs: ["carter"], note: "Reload proof", arrivedAt: "test")
        clean.setAttendance(spielID: "sp1", curlerID: "me", isGoing: false, updatedAt: "test")

        var game = clean.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")!
        _ = clean.setBonspielResultFlags(bonspielID: "bon-brier-patch-open", gameID: "bp-g1", conceded: true, forfeited: false)
        _ = clean.recordBonspielEndScore(bonspielID: "bon-brier-patch-open",
                                         gameID: "bp-g1",
                                         endNumber: (game.ends.map(\.endNumber).max() ?? 0) + 1,
                                         teamA: 1,
                                         teamB: 0)
        game = clean.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")!
        XCTAssertNotNil(game)
        _ = clean.confirmBonspielGameResult(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")

        let reloaded = Store(loadPersisted: true)

        XCTAssertTrue(reloaded.setupComplete)
        XCTAssertTrue(reloaded.results.contains { $0.note == "Clean install loop result" })
        XCTAssertTrue(reloaded.isCurrentStop("calgary"))
        XCTAssertFalse(reloaded.isAttendingSpiel("sp1"))
        XCTAssertEqual(reloaded.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.scoreAgreement.confirmed, true)
        XCTAssertEqual(reloaded.results.filter { $0.bonspielGameID == "bp-g1" }.count, 1)
    }
}

final class ReferenceIntegrityTests: XCTestCase {
    func testInvalidReferencesAreRemovedDuringNormalization() {
        var data = Seed.appData(setupComplete: true)
        data.visits.append(StopVisit(stopID: "missing-stop", arrivedAt: "now", departedAt: nil, curlerIDs: ["missing"], note: "bad"))
        data.attendance.append(SpielAttendance(spielID: "missing-spiel", curlerID: "missing", status: .going, updatedAt: "bad"))
        data.results.append(GameResult(authorID: nil,
                                       createdAt: "bad",
                                       note: "bad refs",
                                       opponent: "Missing",
                                       scoreFor: 1,
                                       scoreAgainst: 0,
                                       stopID: "missing-stop",
                                       spielID: "missing-spiel",
                                       participantCurlerIDs: ["missing"],
                                       ends: [],
                                       conceded: false,
                                       forfeited: false,
                                       locallyConfirmed: false))

        let store = Store(appData: data, loadPersisted: false)

        XCTAssertFalse(store.visits.contains { $0.stopID == "missing-stop" })
        XCTAssertFalse(store.attendance.contains { $0.spielID == "missing-spiel" })
        XCTAssertNil(store.results.last?.stopID)
        XCTAssertNil(store.results.last?.spielID)
        XCTAssertEqual(store.results.last?.participantCurlerIDs, [])
    }

    func testBonspielReferencesAreCleanedDuringNormalization() {
        var data = Seed.appData(setupComplete: true)
        data.bonspiels[0].teams[0].members[0].curlerID = "missing-curler"
        data.bonspiels[0].games[0].gameLineups[0].deliveryRotation.append(
            BonspielLineupSlot(memberID: "missing-member", position: "Extra", isSkip: false, isViceSkip: false)
        )
        data.results.append(GameResult(authorID: nil,
                                       createdAt: "bad",
                                       note: "bad bonspiel refs",
                                       opponent: "Missing",
                                       scoreFor: 1,
                                       scoreAgainst: 0,
                                       stopID: nil,
                                       spielID: nil,
                                       participantCurlerIDs: [],
                                       ends: [],
                                       conceded: false,
                                       forfeited: false,
                                       locallyConfirmed: false,
                                       bonspielID: "missing-bonspiel",
                                       bonspielGameID: "missing-game"))

        let store = Store(appData: data, loadPersisted: false)

        XCTAssertNil(store.bonspiel("bon-brier-patch-open")?.teams[0].members[0].curlerID)
        XCTAssertFalse(store.bonspielGame(bonspielID: "bon-brier-patch-open", gameID: "bp-g1")?.gameLineups[0].deliveryRotation.contains(where: { $0.memberID == "missing-member" }) ?? true)
        XCTAssertNil(store.results.last?.bonspielID)
        XCTAssertNil(store.results.last?.bonspielGameID)
    }
}

final class SeedIsolationTests: XCTestCase {
    func testBlankSeasonDoesNotLeakDemoArrays() {
        let store = Store(appData: Seed.appData(setupComplete: true), loadPersisted: false)
        store.startBlankSeason(name: "Alex Stone", homeClub: "Test CC", province: "BC")

        XCTAssertEqual(store.curlers.count, 0)
        XCTAssertEqual(store.venues.count, Seed.venues.count)
        XCTAssertEqual(store.stops.count, 0)
        XCTAssertEqual(store.visits.count, 0)
        XCTAssertEqual(store.spiels.count, 0)
        XCTAssertEqual(store.attendance.count, 0)
        XCTAssertEqual(store.results.count, 0)
        XCTAssertEqual(store.bonspiels.count, 0)
        XCTAssertFalse(store.profile.demoMode)
    }
}
