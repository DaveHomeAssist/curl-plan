import XCTest
@testable import CurlPlanCore

final class AccountFoundationContractTests: XCTestCase {
    func testAccountCanRestoreSeasonOnSecondDeviceThenDeleteAccountRevokesAccess() throws {
        let backend = AccountSocialContractStore()
        let password = "granite-rocks-87"
        let account = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: password)
        let deviceA = try backend.signIn(handle: "dana", password: password, deviceID: "device-a")

        XCTAssertThrowsError(try backend.signIn(handle: "dana", password: "wrong-password-99", deviceID: "device-bad")) { error in
            XCTAssertEqual(error as? AccountBackendError, .invalidCredentials)
        }

        var localSeason = Seed.appData(setupComplete: true)
        localSeason.profile = PlayerProfile.blank(name: "Dana Mercer", homeClub: "Calgary Granite CC", province: "AB")

        try backend.importLocalSeason(sessionID: deviceA.id, season: localSeason)
        backend.signOut(sessionID: deviceA.id)

        XCTAssertThrowsError(try backend.season(sessionID: deviceA.id)) { error in
            XCTAssertEqual(error as? AccountBackendError, .sessionInvalid)
        }

        let deviceB = try backend.signIn(handle: "dana", password: password, deviceID: "device-b")
        let restored = try backend.season(sessionID: deviceB.id)
        XCTAssertEqual(restored.body.profile.name, "Dana Mercer")
        XCTAssertEqual(restored.accountID, account.id)
        XCTAssertEqual(try backend.exportAccountData(sessionID: deviceB.id), ["account", "profile", "season"])

        try backend.deleteAccount(sessionID: deviceB.id)
        XCTAssertThrowsError(try backend.signIn(handle: "dana", password: password, deviceID: "device-c")) { error in
            XCTAssertEqual(error as? AccountBackendError, .invalidCredentials)
        }
        XCTAssertThrowsError(try backend.season(sessionID: deviceB.id)) { error in
            XCTAssertEqual(error as? AccountBackendError, .sessionInvalid)
        }
    }
}

final class CloudSyncContractTests: XCTestCase {
    func testVersionedSyncAcceptsFreshChangeAndRejectsStaleBaseVersion() throws {
        let backend = AccountSocialContractStore()
        let account = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "contract-pass-8")
        let session = try backend.signIn(handle: "dana", password: "contract-pass-8", deviceID: "device-a")
        try backend.importLocalSeason(sessionID: session.id, season: Seed.appData(setupComplete: true))
        let firstVersion = try backend.season(sessionID: session.id).version

        var updated = try backend.season(sessionID: session.id).body
        updated.profile = PlayerProfile.blank(name: "Dana Mercer", homeClub: "Granite Curling Club", province: "AB")

        let receipt = try backend.applySeasonChange(sessionID: session.id,
                                                    baseVersion: firstVersion,
                                                    updatedBody: updated,
                                                    domains: [.profile],
                                                    clientMutationID: "client-1")
        XCTAssertEqual(receipt.baseVersion, 1)
        XCTAssertEqual(receipt.serverVersion, 2)
        XCTAssertEqual(try backend.season(sessionID: session.id).body.profile.homeClub, "Granite Curling Club")

        XCTAssertThrowsError(try backend.applySeasonChange(sessionID: session.id,
                                                           baseVersion: firstVersion,
                                                           updatedBody: updated,
                                                           domains: [.profile],
                                                           clientMutationID: "client-stale")) { error in
            XCTAssertEqual(error as? AccountBackendError, .versionConflict(currentVersion: 2))
        }
    }

    func testOfflineQueueRoundTripsPendingMutationAcrossRelaunch() throws {
        let mutation = OfflineSeasonMutation(id: "offline-1",
                                             seasonID: "season-1",
                                             baseVersion: 4,
                                             clientMutationID: "client-offline-1",
                                             domains: [.results, .feed],
                                             state: "pending")
        let data = try JSONEncoder().encode([mutation])
        let decoded = try JSONDecoder().decode([OfflineSeasonMutation].self, from: data)

        XCTAssertEqual(decoded, [mutation])
        XCTAssertEqual(decoded.first?.state, "pending")
    }
}

final class PublicIdentityAndRelationshipContractTests: XCTestCase {
    func testPrivateProfilesAreNotDiscoverableAndPublicProfilesRespectBlocks() throws {
        let backend = AccountSocialContractStore()
        let dana = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "contract-pass-8")
        let sam = try backend.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "contract-pass-8")
        let danaSession = try backend.signIn(handle: "dana", password: "contract-pass-8", deviceID: "dana-phone")
        let samSession = try backend.signIn(handle: "sam", password: "contract-pass-8", deviceID: "sam-phone")

        XCTAssertEqual(try backend.searchProfiles(sessionID: danaSession.id, query: "sam"), [])

        try backend.updateProfile(sessionID: samSession.id, visibility: .publicProfile, searchable: true)
        XCTAssertEqual(try backend.searchProfiles(sessionID: danaSession.id, query: "sam").map(\.handle), ["sam"])

        try backend.block(sessionID: danaSession.id, targetID: sam.id)
        XCTAssertEqual(try backend.searchProfiles(sessionID: danaSession.id, query: "sam"), [])
        XCTAssertThrowsError(try backend.follow(sessionID: samSession.id, targetID: dana.id)) { error in
            XCTAssertEqual(error as? AccountBackendError, .blocked)
        }
    }

    func testFollowAndUnfollowAreServerBackedRelationshipEdges() throws {
        let backend = AccountSocialContractStore()
        let dana = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "contract-pass-8")
        let sam = try backend.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "contract-pass-8")
        let session = try backend.signIn(handle: "dana", password: "contract-pass-8", deviceID: "dana-phone")

        let follow = try backend.follow(sessionID: session.id, targetID: sam.id)
        XCTAssertEqual(follow.kind, .follow)
        XCTAssertEqual(follow.state, .accepted)
        XCTAssertEqual(backend.relationships.filter { $0.actorID == dana.id && $0.targetID == sam.id && $0.kind == .follow }.count, 1)

        try backend.unfollow(sessionID: session.id, targetID: sam.id)
        XCTAssertFalse(backend.relationships.contains { $0.actorID == dana.id && $0.targetID == sam.id && $0.kind == .follow })
    }
}

final class SharedObjectsAndSafetyContractTests: XCTestCase {
    func testSharedObjectMembershipControlsReadAndEditPermissions() throws {
        let backend = AccountSocialContractStore()
        let dana = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "contract-pass-8")
        let sam = try backend.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "contract-pass-8")
        let jo = try backend.createAccount(handle: "jo", displayName: "Jo Mara", homeClub: "Kelowna CC", password: "contract-pass-8")
        let danaSession = try backend.signIn(handle: "dana", password: "contract-pass-8", deviceID: "dana-phone")
        let samSession = try backend.signIn(handle: "sam", password: "contract-pass-8", deviceID: "sam-phone")
        let joSession = try backend.signIn(handle: "jo", password: "contract-pass-8", deviceID: "jo-phone")
        let spiel = try backend.createSharedObject(sessionID: danaSession.id, kind: .spiel, title: "Brier Patch Open")

        XCTAssertThrowsError(try backend.createInteraction(sessionID: samSession.id,
                                                           objectID: spiel.id,
                                                           kind: .rsvp,
                                                           body: "going")) { error in
            XCTAssertEqual(error as? AccountBackendError, .notMember)
        }

        try backend.addMember(sessionID: danaSession.id, objectID: spiel.id, accountID: sam.id, role: .teammate)
        let rsvp = try backend.createInteraction(sessionID: samSession.id, objectID: spiel.id, kind: .rsvp, body: "going")
        XCTAssertEqual(rsvp.kind, .rsvp)

        try backend.updateSharedObjectTitle(sessionID: samSession.id, objectID: spiel.id, title: "Brier Patch Open - updated")
        XCTAssertEqual(backend.sharedObjects[spiel.id]?.title, "Brier Patch Open - updated")

        XCTAssertThrowsError(try backend.updateSharedObjectTitle(sessionID: joSession.id,
                                                                 objectID: spiel.id,
                                                                 title: "Unauthorized edit")) { error in
            XCTAssertEqual(error as? AccountBackendError, .insufficientRole)
        }
    }

    func testInteractionsCanBeDeletedReportedAndHiddenByModeration() throws {
        let backend = AccountSocialContractStore()
        let dana = try backend.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "contract-pass-8")
        let sam = try backend.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "contract-pass-8")
        let danaSession = try backend.signIn(handle: "dana", password: "contract-pass-8", deviceID: "dana-phone")
        let samSession = try backend.signIn(handle: "sam", password: "contract-pass-8", deviceID: "sam-phone")
        let scorecard = try backend.createSharedObject(sessionID: danaSession.id, kind: .scorecard, title: "Sheet 4")
        try backend.addMember(sessionID: danaSession.id, objectID: scorecard.id, accountID: sam.id, role: .viewer)

        let reaction = try backend.createInteraction(sessionID: samSession.id,
                                                     objectID: scorecard.id,
                                                     kind: .reaction,
                                                     body: "nice shot")
        try backend.deleteInteraction(sessionID: samSession.id, interactionID: reaction.id)
        XCTAssertEqual(backend.interactions[reaction.id]?.state, .deleted)

        let comment = try backend.createInteraction(sessionID: samSession.id,
                                                    objectID: scorecard.id,
                                                    kind: .comment,
                                                    body: "needs review")
        let report = try backend.reportInteraction(sessionID: danaSession.id,
                                                   interactionID: comment.id,
                                                   reason: "unsafe")
        try backend.hideReportedInteraction(reportID: report.id)

        XCTAssertEqual(backend.interactions[comment.id]?.state, .hiddenByModeration)
        XCTAssertEqual(backend.reports.first(where: { $0.id == report.id })?.state, .actioned)
    }
}
