import XCTest
@testable import CurlPlanCore

final class AccountBackendPersistenceTests: XCTestCase {
    func testPersistentTransportRestoresSeasonAfterBackendRestartAndPersistsDeletion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurlPlanAccountBackendPersistenceTests-\(UUID().uuidString)")
        let storageURL = directory.appendingPathComponent("account-backend.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstBackend = try PersistentAccountBackendTransport(storageURL: storageURL)
        let firstDevice = AccountBackendClient(transport: firstBackend)
        let password = "persist-pass-87"
        let account = try firstDevice.createAccount(handle: "dana",
                                                    displayName: "Dana Mercer",
                                                    homeClub: "Calgary Granite CC",
                                                    password: password)
        try firstDevice.signIn(handle: "dana", password: password, deviceID: "device-a")
        var season = AccountSeasonPayload()
        season.profile = AccountSeasonProfile.blank(name: "Dana Mercer", homeClub: "Calgary Granite CC", province: "AB")
        try firstDevice.importLocalSeason(season)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storageURL.path))

        let restartedBackend = try PersistentAccountBackendTransport(storageURL: storageURL)
        let secondDevice = AccountBackendClient(transport: restartedBackend)
        try secondDevice.signIn(handle: "dana", password: password, deviceID: "device-b")

        XCTAssertEqual(try secondDevice.season().body.profile.name, "Dana Mercer")
        XCTAssertEqual(try secondDevice.exportAccountData(), ["account", "profile", "season"])

        try secondDevice.deleteAccount()

        let finalBackend = try PersistentAccountBackendTransport(storageURL: storageURL)
        let deletedSignIn = finalBackend.signIn(handle: "dana", password: password, deviceID: "device-c")

        XCTAssertEqual(deletedSignIn.status, 401)
        XCTAssertEqual(deletedSignIn.error?.code, "INVALID_CREDENTIALS")
        XCTAssertNil(finalBackend.store.profiles[account.id])
        XCTAssertNil(finalBackend.store.seasons[account.id])
    }

    func testPersistentTransportRestoresIdentityGraphSharedObjectsAndModerationState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurlPlanAccountBackendPersistenceTests-\(UUID().uuidString)")
        let storageURL = directory.appendingPathComponent("account-backend.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let backend = try PersistentAccountBackendTransport(storageURL: storageURL)
        let danaClient = AccountBackendClient(transport: backend)
        let samClient = AccountBackendClient(transport: backend)
        let password = "persist-pass-87"
        let dana = try danaClient.createAccount(handle: "dana",
                                                displayName: "Dana Mercer",
                                                homeClub: "Calgary Granite CC",
                                                password: password)
        let sam = try samClient.createAccount(handle: "sam",
                                              displayName: "Sam Reid",
                                              homeClub: "Vernon CC",
                                              password: password)
        try danaClient.signIn(handle: "dana", password: password, deviceID: "dana-phone")
        try samClient.signIn(handle: "sam", password: password, deviceID: "sam-phone")

        try samClient.updateProfile(visibility: .publicProfile, searchable: true)
        try danaClient.follow(targetID: sam.id)
        let scorecard = try danaClient.createSharedObject(kind: .scorecard, title: "Sheet 4")
        try danaClient.addMember(objectID: scorecard.id, accountID: sam.id, role: .viewer)
        let comment = try samClient.createInteraction(objectID: scorecard.id, kind: .comment, body: "needs review")
        let report = try danaClient.reportInteraction(interactionID: comment.id, reason: "unsafe")
        try danaClient.hideReportedInteraction(reportID: report.id)

        let restartedBackend = try PersistentAccountBackendTransport(storageURL: storageURL)
        let reloadedDana = AccountBackendClient(transport: restartedBackend)
        try reloadedDana.signIn(handle: "dana", password: password, deviceID: "dana-tablet")

        XCTAssertEqual(try reloadedDana.searchProfiles(query: "sam").map(\.handle), ["sam"])
        XCTAssertTrue(restartedBackend.store.relationships.contains {
            $0.actorID == dana.id && $0.targetID == sam.id && $0.kind == .follow
        })
        XCTAssertEqual(restartedBackend.store.sharedObjects[scorecard.id]?.title, "Sheet 4")
        XCTAssertEqual(restartedBackend.store.interactions[comment.id]?.state, .hiddenByModeration)
        XCTAssertEqual(restartedBackend.store.reports.first(where: { $0.id == report.id })?.state, .actioned)
    }
}
