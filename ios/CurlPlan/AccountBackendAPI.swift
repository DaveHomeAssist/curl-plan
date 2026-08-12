import Foundation

struct AccountAPIEndpoint: Equatable, Hashable {
    var method: String
    var path: String
}

enum AccountAPIRoutes {
    static let createAccount = AccountAPIEndpoint(method: "POST", path: "/v1/accounts")
    static let signIn = AccountAPIEndpoint(method: "POST", path: "/v1/auth/sign-in")
    static let signOut = AccountAPIEndpoint(method: "POST", path: "/v1/auth/sign-out")
    static let exportAccount = AccountAPIEndpoint(method: "POST", path: "/v1/me/export")
    static let deleteAccount = AccountAPIEndpoint(method: "DELETE", path: "/v1/me")
    static let importSeason = AccountAPIEndpoint(method: "POST", path: "/v1/me/season/import-local")
    static let getSeason = AccountAPIEndpoint(method: "GET", path: "/v1/me/season")
    static let applySeasonChange = AccountAPIEndpoint(method: "POST", path: "/v1/me/season/changes")
    static let updatePrivacy = AccountAPIEndpoint(method: "PATCH", path: "/v1/me/privacy")
    static let searchProfiles = AccountAPIEndpoint(method: "GET", path: "/v1/profiles/search")
    static let follow = AccountAPIEndpoint(method: "POST", path: "/v1/relationships")
    static let unfollow = AccountAPIEndpoint(method: "DELETE", path: "/v1/relationships/follow")
    static let block = AccountAPIEndpoint(method: "POST", path: "/v1/blocks")
    static let createSharedObject = AccountAPIEndpoint(method: "POST", path: "/v1/shared-objects")
    static let addMember = AccountAPIEndpoint(method: "POST", path: "/v1/shared-objects/{id}/members")
    static let updateSharedObject = AccountAPIEndpoint(method: "PATCH", path: "/v1/shared-objects/{id}")
    static let createInteraction = AccountAPIEndpoint(method: "POST", path: "/v1/interactions")
    static let deleteInteraction = AccountAPIEndpoint(method: "DELETE", path: "/v1/interactions/{id}")
    static let reportInteraction = AccountAPIEndpoint(method: "POST", path: "/v1/reports")
    static let moderateReport = AccountAPIEndpoint(method: "POST", path: "/v1/moderation/reports/{id}/hide")
}

struct AccountEmptyResponse: Equatable, Codable {}

struct AccountAPIError: Error, Equatable, Codable {
    var status: Int
    var code: String
    var message: String
    var requestID: String
}

struct AccountAPIResponse<Body: Equatable>: Equatable {
    var endpoint: AccountAPIEndpoint
    var status: Int
    var body: Body?
    var error: AccountAPIError?

    var succeeded: Bool { (200..<300).contains(status) && error == nil }

    static func success(endpoint: AccountAPIEndpoint, status: Int = 200, body: Body) -> AccountAPIResponse<Body> {
        AccountAPIResponse(endpoint: endpoint, status: status, body: body, error: nil)
    }

    static func noContent(endpoint: AccountAPIEndpoint) -> AccountAPIResponse<AccountEmptyResponse> where Body == AccountEmptyResponse {
        AccountAPIResponse<AccountEmptyResponse>(endpoint: endpoint, status: 204, body: AccountEmptyResponse(), error: nil)
    }

    static func failure(endpoint: AccountAPIEndpoint, error: AccountAPIError) -> AccountAPIResponse<Body> {
        AccountAPIResponse(endpoint: endpoint, status: error.status, body: nil, error: error)
    }
}

protocol AccountBackendTransport {
    func createAccount(handle: String, displayName: String, homeClub: String, password: String) -> AccountAPIResponse<CurlPlanAccount>
    func signIn(handle: String, password: String, deviceID: String) -> AccountAPIResponse<AccountSession>
    func signOut(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse>
    func exportAccountData(sessionID: String) -> AccountAPIResponse<[String]>
    func deleteAccount(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse>
    func importLocalSeason(sessionID: String, season: AccountSeasonPayload) -> AccountAPIResponse<AccountSeasonDocument>
    func season(sessionID: String) -> AccountAPIResponse<AccountSeasonDocument>
    func applySeasonChange(sessionID: String,
                           baseVersion: Int,
                           updatedBody: AccountSeasonPayload,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) -> AccountAPIResponse<SeasonChangeReceipt>
    func updateProfile(sessionID: String,
                       visibility: ProfileVisibility,
                       searchable: Bool) -> AccountAPIResponse<AccountEmptyResponse>
    func searchProfiles(sessionID: String, query: String) -> AccountAPIResponse<[AccountProfile]>
    func follow(sessionID: String, targetID: String) -> AccountAPIResponse<RelationshipEdge>
    func unfollow(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse>
    func block(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse>
    func createSharedObject(sessionID: String,
                            kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility) -> AccountAPIResponse<SharedCurlingObject>
    func addMember(sessionID: String,
                   objectID: String,
                   accountID: String,
                   role: MembershipRole) -> AccountAPIResponse<AccountEmptyResponse>
    func updateSharedObjectTitle(sessionID: String,
                                 objectID: String,
                                 title: String) -> AccountAPIResponse<AccountEmptyResponse>
    func createInteraction(sessionID: String,
                           objectID: String,
                           kind: InteractionKind,
                           body: String) -> AccountAPIResponse<SocialInteraction>
    func deleteInteraction(sessionID: String, interactionID: String) -> AccountAPIResponse<AccountEmptyResponse>
    func reportInteraction(sessionID: String,
                           interactionID: String,
                           reason: String) -> AccountAPIResponse<ContentReport>
    func hideReportedInteraction(reportID: String) -> AccountAPIResponse<AccountEmptyResponse>
}

protocol AccountBackendStatePersistence {
    func loadSnapshot() throws -> AccountSocialSnapshot?
    func saveSnapshot(_ snapshot: AccountSocialSnapshot) throws
}

final class FileAccountBackendStatePersistence: AccountBackendStatePersistence {
    private let storageURL: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(storageURL: URL, fileManager: FileManager = .default) {
        self.storageURL = storageURL
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadSnapshot() throws -> AccountSocialSnapshot? {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: storageURL)
        return try decoder.decode(AccountSocialSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: AccountSocialSnapshot) throws {
        let directory = storageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: storageURL, options: [.atomic])
    }
}

final class InMemoryAccountBackendTransport: AccountBackendTransport {
    let store: AccountSocialContractStore
    private var requestCounter = 0

    init(store: AccountSocialContractStore = AccountSocialContractStore()) {
        self.store = store
    }

    func createAccount(handle: String, displayName: String, homeClub: String, password: String) -> AccountAPIResponse<CurlPlanAccount> {
        do {
            let account = try store.createAccount(handle: handle, displayName: displayName, homeClub: homeClub, password: password)
            return .success(endpoint: AccountAPIRoutes.createAccount, status: 201, body: account)
        } catch {
            return failure(AccountAPIRoutes.createAccount, error)
        }
    }

    func signIn(handle: String, password: String, deviceID: String) -> AccountAPIResponse<AccountSession> {
        do {
            return .success(endpoint: AccountAPIRoutes.signIn, body: try store.signIn(handle: handle, password: password, deviceID: deviceID))
        } catch {
            return failure(AccountAPIRoutes.signIn, error)
        }
    }

    func signOut(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        store.signOut(sessionID: sessionID)
        return .noContent(endpoint: AccountAPIRoutes.signOut)
    }

    func exportAccountData(sessionID: String) -> AccountAPIResponse<[String]> {
        do {
            return .success(endpoint: AccountAPIRoutes.exportAccount, body: try store.exportAccountData(sessionID: sessionID))
        } catch {
            return failure(AccountAPIRoutes.exportAccount, error)
        }
    }

    func deleteAccount(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.deleteAccount(sessionID: sessionID)
            return .noContent(endpoint: AccountAPIRoutes.deleteAccount)
        } catch {
            return failure(AccountAPIRoutes.deleteAccount, error)
        }
    }

    func importLocalSeason(sessionID: String, season: AccountSeasonPayload) -> AccountAPIResponse<AccountSeasonDocument> {
        do {
            return .success(endpoint: AccountAPIRoutes.importSeason,
                            status: 201,
                            body: try store.importLocalSeason(sessionID: sessionID, season: season))
        } catch {
            return failure(AccountAPIRoutes.importSeason, error)
        }
    }

    func season(sessionID: String) -> AccountAPIResponse<AccountSeasonDocument> {
        do {
            return .success(endpoint: AccountAPIRoutes.getSeason, body: try store.season(sessionID: sessionID))
        } catch {
            return failure(AccountAPIRoutes.getSeason, error)
        }
    }

    func applySeasonChange(sessionID: String,
                           baseVersion: Int,
                           updatedBody: AccountSeasonPayload,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) -> AccountAPIResponse<SeasonChangeReceipt> {
        do {
            return .success(endpoint: AccountAPIRoutes.applySeasonChange,
                            body: try store.applySeasonChange(sessionID: sessionID,
                                                              baseVersion: baseVersion,
                                                              updatedBody: updatedBody,
                                                              domains: domains,
                                                              clientMutationID: clientMutationID))
        } catch {
            return failure(AccountAPIRoutes.applySeasonChange, error)
        }
    }

    func updateProfile(sessionID: String,
                       visibility: ProfileVisibility,
                       searchable: Bool) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.updateProfile(sessionID: sessionID, visibility: visibility, searchable: searchable)
            return .noContent(endpoint: AccountAPIRoutes.updatePrivacy)
        } catch {
            return failure(AccountAPIRoutes.updatePrivacy, error)
        }
    }

    func searchProfiles(sessionID: String, query: String) -> AccountAPIResponse<[AccountProfile]> {
        do {
            return .success(endpoint: AccountAPIRoutes.searchProfiles, body: try store.searchProfiles(sessionID: sessionID, query: query))
        } catch {
            return failure(AccountAPIRoutes.searchProfiles, error)
        }
    }

    func follow(sessionID: String, targetID: String) -> AccountAPIResponse<RelationshipEdge> {
        do {
            return .success(endpoint: AccountAPIRoutes.follow, status: 201, body: try store.follow(sessionID: sessionID, targetID: targetID))
        } catch {
            return failure(AccountAPIRoutes.follow, error)
        }
    }

    func unfollow(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.unfollow(sessionID: sessionID, targetID: targetID)
            return .noContent(endpoint: AccountAPIRoutes.unfollow)
        } catch {
            return failure(AccountAPIRoutes.unfollow, error)
        }
    }

    func block(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.block(sessionID: sessionID, targetID: targetID)
            return .noContent(endpoint: AccountAPIRoutes.block)
        } catch {
            return failure(AccountAPIRoutes.block, error)
        }
    }

    func createSharedObject(sessionID: String,
                            kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility) -> AccountAPIResponse<SharedCurlingObject> {
        do {
            return .success(endpoint: AccountAPIRoutes.createSharedObject,
                            status: 201,
                            body: try store.createSharedObject(sessionID: sessionID,
                                                               kind: kind,
                                                               title: title,
                                                               visibility: visibility))
        } catch {
            return failure(AccountAPIRoutes.createSharedObject, error)
        }
    }

    func addMember(sessionID: String,
                   objectID: String,
                   accountID: String,
                   role: MembershipRole) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.addMember(sessionID: sessionID, objectID: objectID, accountID: accountID, role: role)
            return .noContent(endpoint: AccountAPIRoutes.addMember)
        } catch {
            return failure(AccountAPIRoutes.addMember, error)
        }
    }

    func updateSharedObjectTitle(sessionID: String,
                                 objectID: String,
                                 title: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.updateSharedObjectTitle(sessionID: sessionID, objectID: objectID, title: title)
            return .noContent(endpoint: AccountAPIRoutes.updateSharedObject)
        } catch {
            return failure(AccountAPIRoutes.updateSharedObject, error)
        }
    }

    func createInteraction(sessionID: String,
                           objectID: String,
                           kind: InteractionKind,
                           body: String) -> AccountAPIResponse<SocialInteraction> {
        do {
            return .success(endpoint: AccountAPIRoutes.createInteraction,
                            status: 201,
                            body: try store.createInteraction(sessionID: sessionID,
                                                              objectID: objectID,
                                                              kind: kind,
                                                              body: body))
        } catch {
            return failure(AccountAPIRoutes.createInteraction, error)
        }
    }

    func deleteInteraction(sessionID: String, interactionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.deleteInteraction(sessionID: sessionID, interactionID: interactionID)
            return .noContent(endpoint: AccountAPIRoutes.deleteInteraction)
        } catch {
            return failure(AccountAPIRoutes.deleteInteraction, error)
        }
    }

    func reportInteraction(sessionID: String,
                           interactionID: String,
                           reason: String) -> AccountAPIResponse<ContentReport> {
        do {
            return .success(endpoint: AccountAPIRoutes.reportInteraction,
                            status: 201,
                            body: try store.reportInteraction(sessionID: sessionID,
                                                              interactionID: interactionID,
                                                              reason: reason))
        } catch {
            return failure(AccountAPIRoutes.reportInteraction, error)
        }
    }

    func hideReportedInteraction(reportID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        do {
            try store.hideReportedInteraction(reportID: reportID)
            return .noContent(endpoint: AccountAPIRoutes.moderateReport)
        } catch {
            return failure(AccountAPIRoutes.moderateReport, error)
        }
    }

    private func failure<Body: Equatable>(_ endpoint: AccountAPIEndpoint, _ error: Error) -> AccountAPIResponse<Body> {
        AccountAPIResponse<Body>.failure(endpoint: endpoint, error: apiError(for: error))
    }

    private func apiError(for error: Error) -> AccountAPIError {
        requestCounter += 1
        let requestID = "req-\(requestCounter)"
        guard let backendError = error as? AccountBackendError else {
            return AccountAPIError(status: 500,
                                   code: "INTERNAL_ERROR",
                                   message: "Unexpected backend error.",
                                   requestID: requestID)
        }
        switch backendError {
        case .sessionInvalid:
            return AccountAPIError(status: 401, code: "SESSION_INVALID", message: "Sign in again.", requestID: requestID)
        case .accountDeleted:
            return AccountAPIError(status: 403, code: "ACCOUNT_DELETED", message: "Account has been deleted.", requestID: requestID)
        case .invalidCredentials:
            return AccountAPIError(status: 401, code: "INVALID_CREDENTIALS", message: "Handle or password is incorrect.", requestID: requestID)
        case .weakPassword:
            return AccountAPIError(status: 422, code: "WEAK_PASSWORD", message: "Password is too short.", requestID: requestID)
        case .handleTaken:
            return AccountAPIError(status: 409, code: "HANDLE_TAKEN", message: "That handle is already reserved.", requestID: requestID)
        case .blocked:
            return AccountAPIError(status: 403, code: "BLOCKED", message: "Relationship is blocked.", requestID: requestID)
        case .notMember:
            return AccountAPIError(status: 403, code: "NOT_MEMBER", message: "Membership is required.", requestID: requestID)
        case .insufficientRole:
            return AccountAPIError(status: 403, code: "INSUFFICIENT_ROLE", message: "Role cannot perform this action.", requestID: requestID)
        case .privateProfile:
            return AccountAPIError(status: 403, code: "PRIVATE_PROFILE", message: "Profile is private.", requestID: requestID)
        case .accountNotFound:
            return AccountAPIError(status: 404, code: "ACCOUNT_NOT_FOUND", message: "Account was not found.", requestID: requestID)
        case .seasonMissing:
            return AccountAPIError(status: 404, code: "SEASON_MISSING", message: "Season document was not found.", requestID: requestID)
        case .notFound:
            return AccountAPIError(status: 404, code: "NOT_FOUND", message: "Resource was not found.", requestID: requestID)
        case .seasonAlreadyExists:
            return AccountAPIError(status: 409, code: "SEASON_ALREADY_EXISTS", message: "Account already has a season document.", requestID: requestID)
        case .versionConflict(let currentVersion):
            return AccountAPIError(status: 409,
                                   code: "VERSION_CONFLICT",
                                   message: "Current version is \(currentVersion).",
                                   requestID: requestID)
        case .rateLimited:
            return AccountAPIError(status: 429, code: "RATE_LIMITED", message: "Retry later.", requestID: requestID)
        }
    }
}

final class PersistentAccountBackendTransport: AccountBackendTransport {
    let store: AccountSocialContractStore
    private let transport: InMemoryAccountBackendTransport
    private let persistence: AccountBackendStatePersistence
    private var requestCounter = 0

    convenience init(storageURL: URL) throws {
        try self.init(persistence: FileAccountBackendStatePersistence(storageURL: storageURL))
    }

    init(persistence: AccountBackendStatePersistence) throws {
        self.persistence = persistence
        store = AccountSocialContractStore(snapshot: try persistence.loadSnapshot() ?? .empty)
        transport = InMemoryAccountBackendTransport(store: store)
    }

    func createAccount(handle: String, displayName: String, homeClub: String, password: String) -> AccountAPIResponse<CurlPlanAccount> {
        persist(transport.createAccount(handle: handle, displayName: displayName, homeClub: homeClub, password: password))
    }

    func signIn(handle: String, password: String, deviceID: String) -> AccountAPIResponse<AccountSession> {
        persist(transport.signIn(handle: handle, password: password, deviceID: deviceID))
    }

    func signOut(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.signOut(sessionID: sessionID))
    }

    func exportAccountData(sessionID: String) -> AccountAPIResponse<[String]> {
        transport.exportAccountData(sessionID: sessionID)
    }

    func deleteAccount(sessionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.deleteAccount(sessionID: sessionID))
    }

    func importLocalSeason(sessionID: String, season: AccountSeasonPayload) -> AccountAPIResponse<AccountSeasonDocument> {
        persist(transport.importLocalSeason(sessionID: sessionID, season: season))
    }

    func season(sessionID: String) -> AccountAPIResponse<AccountSeasonDocument> {
        transport.season(sessionID: sessionID)
    }

    func applySeasonChange(sessionID: String,
                           baseVersion: Int,
                           updatedBody: AccountSeasonPayload,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) -> AccountAPIResponse<SeasonChangeReceipt> {
        persist(transport.applySeasonChange(sessionID: sessionID,
                                            baseVersion: baseVersion,
                                            updatedBody: updatedBody,
                                            domains: domains,
                                            clientMutationID: clientMutationID))
    }

    func updateProfile(sessionID: String,
                       visibility: ProfileVisibility,
                       searchable: Bool) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.updateProfile(sessionID: sessionID, visibility: visibility, searchable: searchable))
    }

    func searchProfiles(sessionID: String, query: String) -> AccountAPIResponse<[AccountProfile]> {
        transport.searchProfiles(sessionID: sessionID, query: query)
    }

    func follow(sessionID: String, targetID: String) -> AccountAPIResponse<RelationshipEdge> {
        persist(transport.follow(sessionID: sessionID, targetID: targetID))
    }

    func unfollow(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.unfollow(sessionID: sessionID, targetID: targetID))
    }

    func block(sessionID: String, targetID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.block(sessionID: sessionID, targetID: targetID))
    }

    func createSharedObject(sessionID: String,
                            kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility) -> AccountAPIResponse<SharedCurlingObject> {
        persist(transport.createSharedObject(sessionID: sessionID, kind: kind, title: title, visibility: visibility))
    }

    func addMember(sessionID: String,
                   objectID: String,
                   accountID: String,
                   role: MembershipRole) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.addMember(sessionID: sessionID, objectID: objectID, accountID: accountID, role: role))
    }

    func updateSharedObjectTitle(sessionID: String,
                                 objectID: String,
                                 title: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.updateSharedObjectTitle(sessionID: sessionID, objectID: objectID, title: title))
    }

    func createInteraction(sessionID: String,
                           objectID: String,
                           kind: InteractionKind,
                           body: String) -> AccountAPIResponse<SocialInteraction> {
        persist(transport.createInteraction(sessionID: sessionID, objectID: objectID, kind: kind, body: body))
    }

    func deleteInteraction(sessionID: String, interactionID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.deleteInteraction(sessionID: sessionID, interactionID: interactionID))
    }

    func reportInteraction(sessionID: String,
                           interactionID: String,
                           reason: String) -> AccountAPIResponse<ContentReport> {
        persist(transport.reportInteraction(sessionID: sessionID, interactionID: interactionID, reason: reason))
    }

    func hideReportedInteraction(reportID: String) -> AccountAPIResponse<AccountEmptyResponse> {
        persist(transport.hideReportedInteraction(reportID: reportID))
    }

    private func persist<Body: Equatable>(_ response: AccountAPIResponse<Body>) -> AccountAPIResponse<Body> {
        guard response.succeeded else {
            return response
        }
        do {
            try persistence.saveSnapshot(store.snapshot())
            return response
        } catch {
            requestCounter += 1
            return .failure(endpoint: response.endpoint,
                            error: AccountAPIError(status: 500,
                                                   code: "PERSISTENCE_FAILED",
                                                   message: "Backend state could not be saved.",
                                                   requestID: "persist-\(requestCounter)"))
        }
    }
}

final class AccountBackendClient {
    private let transport: AccountBackendTransport
    private(set) var session: AccountSession?

    init(transport: AccountBackendTransport) {
        self.transport = transport
    }

    @discardableResult
    func createAccount(handle: String, displayName: String, homeClub: String, password: String) throws -> CurlPlanAccount {
        try unwrap(transport.createAccount(handle: handle, displayName: displayName, homeClub: homeClub, password: password))
    }

    @discardableResult
    func signIn(handle: String, password: String, deviceID: String) throws -> AccountSession {
        let session = try unwrap(transport.signIn(handle: handle, password: password, deviceID: deviceID))
        self.session = session
        return session
    }

    func signOut() throws {
        _ = try unwrap(transport.signOut(sessionID: try requireSessionID()))
        session = nil
    }

    func exportAccountData() throws -> [String] {
        try unwrap(transport.exportAccountData(sessionID: try requireSessionID()))
    }

    func deleteAccount() throws {
        _ = try unwrap(transport.deleteAccount(sessionID: try requireSessionID()))
        session = nil
    }

    @discardableResult
    func importLocalSeason(_ season: AccountSeasonPayload) throws -> AccountSeasonDocument {
        try unwrap(transport.importLocalSeason(sessionID: try requireSessionID(), season: season))
    }

    func season() throws -> AccountSeasonDocument {
        try unwrap(transport.season(sessionID: try requireSessionID()))
    }

    @discardableResult
    func applySeasonChange(baseVersion: Int,
                           updatedBody: AccountSeasonPayload,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) throws -> SeasonChangeReceipt {
        try unwrap(transport.applySeasonChange(sessionID: try requireSessionID(),
                                               baseVersion: baseVersion,
                                               updatedBody: updatedBody,
                                               domains: domains,
                                               clientMutationID: clientMutationID))
    }

    func updateProfile(visibility: ProfileVisibility, searchable: Bool) throws {
        _ = try unwrap(transport.updateProfile(sessionID: try requireSessionID(),
                                               visibility: visibility,
                                               searchable: searchable))
    }

    func searchProfiles(query: String) throws -> [AccountProfile] {
        try unwrap(transport.searchProfiles(sessionID: try requireSessionID(), query: query))
    }

    @discardableResult
    func follow(targetID: String) throws -> RelationshipEdge {
        try unwrap(transport.follow(sessionID: try requireSessionID(), targetID: targetID))
    }

    func unfollow(targetID: String) throws {
        _ = try unwrap(transport.unfollow(sessionID: try requireSessionID(), targetID: targetID))
    }

    func block(targetID: String) throws {
        _ = try unwrap(transport.block(sessionID: try requireSessionID(), targetID: targetID))
    }

    @discardableResult
    func createSharedObject(kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility = .membersOnly) throws -> SharedCurlingObject {
        try unwrap(transport.createSharedObject(sessionID: try requireSessionID(),
                                                kind: kind,
                                                title: title,
                                                visibility: visibility))
    }

    func addMember(objectID: String, accountID: String, role: MembershipRole) throws {
        _ = try unwrap(transport.addMember(sessionID: try requireSessionID(),
                                           objectID: objectID,
                                           accountID: accountID,
                                           role: role))
    }

    func updateSharedObjectTitle(objectID: String, title: String) throws {
        _ = try unwrap(transport.updateSharedObjectTitle(sessionID: try requireSessionID(),
                                                         objectID: objectID,
                                                         title: title))
    }

    @discardableResult
    func createInteraction(objectID: String,
                           kind: InteractionKind,
                           body: String) throws -> SocialInteraction {
        try unwrap(transport.createInteraction(sessionID: try requireSessionID(),
                                               objectID: objectID,
                                               kind: kind,
                                               body: body))
    }

    func deleteInteraction(interactionID: String) throws {
        _ = try unwrap(transport.deleteInteraction(sessionID: try requireSessionID(), interactionID: interactionID))
    }

    @discardableResult
    func reportInteraction(interactionID: String, reason: String) throws -> ContentReport {
        try unwrap(transport.reportInteraction(sessionID: try requireSessionID(),
                                               interactionID: interactionID,
                                               reason: reason))
    }

    func hideReportedInteraction(reportID: String) throws {
        _ = try unwrap(transport.hideReportedInteraction(reportID: reportID))
    }

    private func requireSessionID() throws -> String {
        guard let session else {
            throw AccountAPIError(status: 401,
                                  code: "CLIENT_SIGNED_OUT",
                                  message: "Client has no active session.",
                                  requestID: "client")
        }
        return session.id
    }

    private func unwrap<Body>(_ response: AccountAPIResponse<Body>) throws -> Body {
        if let error = response.error {
            throw error
        }
        guard let body = response.body else {
            throw AccountAPIError(status: 500,
                                  code: "MISSING_RESPONSE_BODY",
                                  message: "Backend response had no body.",
                                  requestID: "client")
        }
        return body
    }
}
