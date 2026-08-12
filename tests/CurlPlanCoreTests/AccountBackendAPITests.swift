import XCTest
@testable import CurlPlanCore

final class AccountBackendAPITests: XCTestCase {
    func testClientRestoresAccountSeasonAcrossDevicesAndDeletionBlocksFutureSignIn() throws {
        let transport = InMemoryAccountBackendTransport()
        let deviceA = AccountBackendClient(transport: transport)
        let account = try deviceA.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "api-pass-87")
        try deviceA.signIn(handle: "dana", password: "api-pass-87", deviceID: "device-a")
        var season = AccountSeasonPayload()
        season.profile = AccountSeasonProfile.blank(name: "Dana Mercer", homeClub: "Calgary Granite CC", province: "AB")
        try deviceA.importLocalSeason(season)

        try deviceA.signOut()
        XCTAssertThrowsAPIError(try deviceA.season(), status: 401, code: "CLIENT_SIGNED_OUT")

        let deviceB = AccountBackendClient(transport: transport)
        try deviceB.signIn(handle: "dana", password: "api-pass-87", deviceID: "device-b")
        XCTAssertEqual(try deviceB.season().body.profile.name, "Dana Mercer")
        XCTAssertEqual(try deviceB.exportAccountData(), ["account", "profile", "season"])

        try deviceB.deleteAccount()
        let deletedSignIn = transport.signIn(handle: "dana", password: "api-pass-87", deviceID: "device-c")
        XCTAssertEqual(deletedSignIn.status, 401)
        XCTAssertEqual(deletedSignIn.error?.code, "INVALID_CREDENTIALS")
    }

    func testSyncEndpointReturnsConflictForStaleBaseVersion() throws {
        let transport = InMemoryAccountBackendTransport()
        let client = AccountBackendClient(transport: transport)
        let account = try client.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "api-pass-87")
        let session = try client.signIn(handle: "dana", password: "api-pass-87", deviceID: "device-a")
        try client.importLocalSeason(AccountSeasonPayload())
        let baseVersion = try client.season().version

        var update = try client.season().body
        update.profile = AccountSeasonProfile.blank(name: "Dana Mercer", homeClub: "Granite Curling Club", province: "AB")
        let receipt = try client.applySeasonChange(baseVersion: baseVersion,
                                                   updatedBody: update,
                                                   domains: [.profile],
                                                   clientMutationID: "client-1")
        XCTAssertEqual(receipt.serverVersion, 2)

        let stale = transport.applySeasonChange(sessionID: session.id,
                                                baseVersion: baseVersion,
                                                updatedBody: update,
                                                domains: [.profile],
                                                clientMutationID: "client-stale")
        XCTAssertEqual(stale.status, 409)
        XCTAssertEqual(stale.error?.code, "VERSION_CONFLICT")
        XCTAssertEqual(stale.endpoint, AccountAPIRoutes.applySeasonChange)
    }

    func testPublicIdentityAndRelationshipEndpointsRespectPrivacyAndBlockState() throws {
        let transport = InMemoryAccountBackendTransport()
        let danaClient = AccountBackendClient(transport: transport)
        let samClient = AccountBackendClient(transport: transport)
        let dana = try danaClient.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "api-pass-87")
        let sam = try samClient.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "api-pass-87")
        try danaClient.signIn(handle: "dana", password: "api-pass-87", deviceID: "dana-phone")
        try samClient.signIn(handle: "sam", password: "api-pass-87", deviceID: "sam-phone")

        XCTAssertEqual(try danaClient.searchProfiles(query: "sam"), [])
        try samClient.updateProfile(visibility: .publicProfile, searchable: true)
        XCTAssertEqual(try danaClient.searchProfiles(query: "sam").map(\.handle), ["sam"])

        try danaClient.block(targetID: sam.id)
        XCTAssertEqual(try danaClient.searchProfiles(query: "sam"), [])
        XCTAssertThrowsAPIError(try samClient.follow(targetID: dana.id), status: 403, code: "BLOCKED")
    }

    func testSharedObjectInteractionAndModerationEndpointsPreservePermissionBoundaries() throws {
        let transport = InMemoryAccountBackendTransport()
        let danaClient = AccountBackendClient(transport: transport)
        let samClient = AccountBackendClient(transport: transport)
        let joClient = AccountBackendClient(transport: transport)
        let dana = try danaClient.createAccount(handle: "dana", displayName: "Dana Mercer", homeClub: "Calgary Granite CC", password: "api-pass-87")
        let sam = try samClient.createAccount(handle: "sam", displayName: "Sam Reid", homeClub: "Vernon CC", password: "api-pass-87")
        let jo = try joClient.createAccount(handle: "jo", displayName: "Jo Mara", homeClub: "Kelowna CC", password: "api-pass-87")
        try danaClient.signIn(handle: "dana", password: "api-pass-87", deviceID: "dana-phone")
        try samClient.signIn(handle: "sam", password: "api-pass-87", deviceID: "sam-phone")
        try joClient.signIn(handle: "jo", password: "api-pass-87", deviceID: "jo-phone")

        let scorecard = try danaClient.createSharedObject(kind: .scorecard, title: "Sheet 4")
        XCTAssertThrowsAPIError(try samClient.createInteraction(objectID: scorecard.id, kind: .rsvp, body: "going"),
                                status: 403,
                                code: "NOT_MEMBER")

        try danaClient.addMember(objectID: scorecard.id, accountID: sam.id, role: .viewer)
        let comment = try samClient.createInteraction(objectID: scorecard.id, kind: .comment, body: "needs review")
        let report = try danaClient.reportInteraction(interactionID: comment.id, reason: "unsafe")
        try danaClient.hideReportedInteraction(reportID: report.id)
        XCTAssertEqual(transport.store.interactions[comment.id]?.state, .hiddenByModeration)

        XCTAssertThrowsAPIError(try joClient.updateSharedObjectTitle(objectID: scorecard.id, title: "Unauthorized"),
                                status: 403,
                                code: "INSUFFICIENT_ROLE")
    }
}

private func XCTAssertThrowsAPIError<T>(_ expression: @autoclosure () throws -> T,
                                        status: Int,
                                        code: String,
                                        file: StaticString = #filePath,
                                        line: UInt = #line) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
        guard let apiError = error as? AccountAPIError else {
            XCTFail("Expected AccountAPIError, got \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(apiError.status, status, file: file, line: line)
        XCTAssertEqual(apiError.code, code, file: file, line: line)
    }
}
