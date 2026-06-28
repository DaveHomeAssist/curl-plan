import Foundation

enum AccountHTTPTransportError: Error {
    case invalidResponse
}

struct AccountCreateRequest: Equatable, Codable {
    var handle: String
    var displayName: String
    var homeClub: String
    var password: String
}

struct AccountSignInRequest: Equatable, Codable {
    var handle: String
    var password: String
    var deviceID: String
}

struct AccountImportSeasonRequest: Equatable, Codable {
    var season: AppData
}

struct AccountApplySeasonChangeRequest: Equatable, Codable {
    var baseVersion: Int
    var updatedBody: AppData
    var domains: Set<SeasonDomain>
    var clientMutationID: String
}

struct AccountUpdateProfileRequest: Equatable, Codable {
    var visibility: ProfileVisibility
    var searchable: Bool
}

struct AccountRelationshipRequest: Equatable, Codable {
    var targetID: String
}

struct AccountCreateSharedObjectRequest: Equatable, Codable {
    var kind: SharedObjectKind
    var title: String
    var visibility: SharedVisibility
}

struct AccountAddMemberRequest: Equatable, Codable {
    var accountID: String
    var role: MembershipRole
}

struct AccountUpdateSharedObjectRequest: Equatable, Codable {
    var title: String
}

struct AccountCreateInteractionRequest: Equatable, Codable {
    var objectID: String
    var kind: InteractionKind
    var body: String
}

struct AccountReportInteractionRequest: Equatable, Codable {
    var interactionID: String
    var reason: String
}

struct AccountHTTPErrorEnvelope: Equatable, Codable {
    var error: AccountAPIError
}

protocol AccountHTTPDataLoading {
    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: AccountHTTPDataLoading {
    func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountHTTPTransportError.invalidResponse
        }
        return (data, httpResponse)
    }
}

final class AccountHTTPBackendTransport {
    private let baseURL: URL
    private let loader: AccountHTTPDataLoading
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL, loader: AccountHTTPDataLoading = URLSession.shared) {
        self.baseURL = baseURL
        self.loader = loader
    }

    func createAccount(handle: String, displayName: String, homeClub: String, password: String) async -> AccountAPIResponse<CurlPlanAccount> {
        await send(AccountAPIRoutes.createAccount,
                   body: AccountCreateRequest(handle: handle, displayName: displayName, homeClub: homeClub, password: password),
                   response: CurlPlanAccount.self)
    }

    func signIn(handle: String, password: String, deviceID: String) async -> AccountAPIResponse<AccountSession> {
        await send(AccountAPIRoutes.signIn,
                   body: AccountSignInRequest(handle: handle, password: password, deviceID: deviceID),
                   response: AccountSession.self)
    }

    func signOut(sessionID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.signOut,
                   sessionID: sessionID,
                   response: AccountEmptyResponse.self)
    }

    func exportAccountData(sessionID: String) async -> AccountAPIResponse<[String]> {
        await send(AccountAPIRoutes.exportAccount,
                   sessionID: sessionID,
                   response: [String].self)
    }

    func deleteAccount(sessionID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.deleteAccount,
                   sessionID: sessionID,
                   response: AccountEmptyResponse.self)
    }

    func importLocalSeason(sessionID: String, season: AppData) async -> AccountAPIResponse<AccountSeasonDocument> {
        await send(AccountAPIRoutes.importSeason,
                   sessionID: sessionID,
                   body: AccountImportSeasonRequest(season: season),
                   response: AccountSeasonDocument.self)
    }

    func season(sessionID: String) async -> AccountAPIResponse<AccountSeasonDocument> {
        await send(AccountAPIRoutes.getSeason,
                   sessionID: sessionID,
                   response: AccountSeasonDocument.self)
    }

    func applySeasonChange(sessionID: String,
                           baseVersion: Int,
                           updatedBody: AppData,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) async -> AccountAPIResponse<SeasonChangeReceipt> {
        await send(AccountAPIRoutes.applySeasonChange,
                   sessionID: sessionID,
                   body: AccountApplySeasonChangeRequest(baseVersion: baseVersion,
                                                         updatedBody: updatedBody,
                                                         domains: domains,
                                                         clientMutationID: clientMutationID),
                   response: SeasonChangeReceipt.self)
    }

    func updateProfile(sessionID: String,
                       visibility: ProfileVisibility,
                       searchable: Bool) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.updatePrivacy,
                   sessionID: sessionID,
                   body: AccountUpdateProfileRequest(visibility: visibility, searchable: searchable),
                   response: AccountEmptyResponse.self)
    }

    func searchProfiles(sessionID: String, query: String) async -> AccountAPIResponse<[AccountProfile]> {
        await send(AccountAPIRoutes.searchProfiles,
                   sessionID: sessionID,
                   queryItems: [URLQueryItem(name: "q", value: query)],
                   response: [AccountProfile].self)
    }

    func follow(sessionID: String, targetID: String) async -> AccountAPIResponse<RelationshipEdge> {
        await send(AccountAPIRoutes.follow,
                   sessionID: sessionID,
                   body: AccountRelationshipRequest(targetID: targetID),
                   response: RelationshipEdge.self)
    }

    func unfollow(sessionID: String, targetID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.unfollow,
                   sessionID: sessionID,
                   body: AccountRelationshipRequest(targetID: targetID),
                   response: AccountEmptyResponse.self)
    }

    func block(sessionID: String, targetID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.block,
                   sessionID: sessionID,
                   body: AccountRelationshipRequest(targetID: targetID),
                   response: AccountEmptyResponse.self)
    }

    func createSharedObject(sessionID: String,
                            kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility) async -> AccountAPIResponse<SharedCurlingObject> {
        await send(AccountAPIRoutes.createSharedObject,
                   sessionID: sessionID,
                   body: AccountCreateSharedObjectRequest(kind: kind, title: title, visibility: visibility),
                   response: SharedCurlingObject.self)
    }

    func addMember(sessionID: String,
                   objectID: String,
                   accountID: String,
                   role: MembershipRole) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.addMember,
                   sessionID: sessionID,
                   pathValues: ["id": objectID],
                   body: AccountAddMemberRequest(accountID: accountID, role: role),
                   response: AccountEmptyResponse.self)
    }

    func updateSharedObjectTitle(sessionID: String,
                                 objectID: String,
                                 title: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.updateSharedObject,
                   sessionID: sessionID,
                   pathValues: ["id": objectID],
                   body: AccountUpdateSharedObjectRequest(title: title),
                   response: AccountEmptyResponse.self)
    }

    func createInteraction(sessionID: String,
                           objectID: String,
                           kind: InteractionKind,
                           body: String) async -> AccountAPIResponse<SocialInteraction> {
        await send(AccountAPIRoutes.createInteraction,
                   sessionID: sessionID,
                   body: AccountCreateInteractionRequest(objectID: objectID, kind: kind, body: body),
                   response: SocialInteraction.self)
    }

    func deleteInteraction(sessionID: String, interactionID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.deleteInteraction,
                   sessionID: sessionID,
                   pathValues: ["id": interactionID],
                   response: AccountEmptyResponse.self)
    }

    func reportInteraction(sessionID: String,
                           interactionID: String,
                           reason: String) async -> AccountAPIResponse<ContentReport> {
        await send(AccountAPIRoutes.reportInteraction,
                   sessionID: sessionID,
                   body: AccountReportInteractionRequest(interactionID: interactionID, reason: reason),
                   response: ContentReport.self)
    }

    func hideReportedInteraction(reportID: String) async -> AccountAPIResponse<AccountEmptyResponse> {
        await send(AccountAPIRoutes.moderateReport,
                   pathValues: ["id": reportID],
                   response: AccountEmptyResponse.self)
    }

    private func send<Body: Codable & Equatable>(_ endpoint: AccountAPIEndpoint,
                                                 sessionID: String? = nil,
                                                 pathValues: [String: String] = [:],
                                                 queryItems: [URLQueryItem] = [],
                                                 response: Body.Type) async -> AccountAPIResponse<Body> {
        await send(endpoint,
                   sessionID: sessionID,
                   pathValues: pathValues,
                   queryItems: queryItems,
                   requestBody: Optional<AccountEmptyResponse>.none,
                   response: response)
    }

    private func send<RequestBody: Encodable, Body: Codable & Equatable>(_ endpoint: AccountAPIEndpoint,
                                                                         sessionID: String? = nil,
                                                                         pathValues: [String: String] = [:],
                                                                         queryItems: [URLQueryItem] = [],
                                                                         body requestBody: RequestBody,
                                                                         response: Body.Type) async -> AccountAPIResponse<Body> {
        await send(endpoint,
                   sessionID: sessionID,
                   pathValues: pathValues,
                   queryItems: queryItems,
                   requestBody: requestBody,
                   response: response)
    }

    private func send<RequestBody: Encodable, Body: Codable & Equatable>(_ endpoint: AccountAPIEndpoint,
                                                                         sessionID: String?,
                                                                         pathValues: [String: String],
                                                                         queryItems: [URLQueryItem],
                                                                         requestBody: RequestBody?,
                                                                         response: Body.Type) async -> AccountAPIResponse<Body> {
        do {
            let request = try makeRequest(endpoint: endpoint,
                                          sessionID: sessionID,
                                          pathValues: pathValues,
                                          queryItems: queryItems,
                                          body: requestBody)
            let (data, httpResponse) = try await loader.load(request)
            return decode(endpoint: endpoint,
                          status: httpResponse.statusCode,
                          data: data,
                          response: response)
        } catch let apiError as AccountAPIError {
            return .failure(endpoint: endpoint, error: apiError)
        } catch {
            return .failure(endpoint: endpoint,
                            error: AccountAPIError(status: 503,
                                                   code: "NETWORK_UNAVAILABLE",
                                                   message: "Account backend request failed.",
                                                   requestID: "network"))
        }
    }

    private func makeRequest<RequestBody: Encodable>(endpoint: AccountAPIEndpoint,
                                                     sessionID: String?,
                                                     pathValues: [String: String],
                                                     queryItems: [URLQueryItem],
                                                     body: RequestBody?) throws -> URLRequest {
        var path = endpoint.path
        for (key, value) in pathValues {
            path = path.replacingOccurrences(of: "{\(key)}", with: value)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                                       resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw AccountAPIError(status: 500,
                                  code: "INVALID_REQUEST_URL",
                                  message: "Account backend URL could not be built.",
                                  requestID: "client")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sessionID {
            request.setValue("Bearer \(sessionID)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func decode<Body: Codable & Equatable>(endpoint: AccountAPIEndpoint,
                                                   status: Int,
                                                   data: Data,
                                                   response: Body.Type) -> AccountAPIResponse<Body> {
        guard (200..<300).contains(status) else {
            return decodeFailure(endpoint: endpoint, status: status, data: data)
        }

        if Body.self == AccountEmptyResponse.self && data.isEmpty {
            return .success(endpoint: endpoint, status: status, body: AccountEmptyResponse() as! Body)
        }

        do {
            return .success(endpoint: endpoint, status: status, body: try decoder.decode(Body.self, from: data))
        } catch {
            return .failure(endpoint: endpoint,
                            error: AccountAPIError(status: 500,
                                                   code: "DECODE_FAILED",
                                                   message: "Account backend response could not be decoded.",
                                                   requestID: "client"))
        }
    }

    private func decodeFailure<Body: Equatable>(endpoint: AccountAPIEndpoint,
                                                status: Int,
                                                data: Data) -> AccountAPIResponse<Body> {
        if let envelope = try? decoder.decode(AccountHTTPErrorEnvelope.self, from: data) {
            return .failure(endpoint: endpoint, error: envelope.error)
        }
        if let error = try? decoder.decode(AccountAPIError.self, from: data) {
            return .failure(endpoint: endpoint, error: error)
        }
        return .failure(endpoint: endpoint,
                        error: AccountAPIError(status: status,
                                               code: "HTTP_\(status)",
                                               message: "Account backend returned HTTP \(status).",
                                               requestID: "http"))
    }
}

final class AccountHTTPBackendClient {
    private let transport: AccountHTTPBackendTransport
    private(set) var session: AccountSession?

    init(transport: AccountHTTPBackendTransport) {
        self.transport = transport
    }

    @discardableResult
    func createAccount(handle: String, displayName: String, homeClub: String, password: String) async throws -> CurlPlanAccount {
        try unwrap(await transport.createAccount(handle: handle, displayName: displayName, homeClub: homeClub, password: password))
    }

    @discardableResult
    func signIn(handle: String, password: String, deviceID: String) async throws -> AccountSession {
        let session = try unwrap(await transport.signIn(handle: handle, password: password, deviceID: deviceID))
        self.session = session
        return session
    }

    func signOut() async throws {
        _ = try unwrap(await transport.signOut(sessionID: try requireSessionID()))
        session = nil
    }

    func exportAccountData() async throws -> [String] {
        try unwrap(await transport.exportAccountData(sessionID: try requireSessionID()))
    }

    func deleteAccount() async throws {
        _ = try unwrap(await transport.deleteAccount(sessionID: try requireSessionID()))
        session = nil
    }

    @discardableResult
    func importLocalSeason(_ season: AppData) async throws -> AccountSeasonDocument {
        try unwrap(await transport.importLocalSeason(sessionID: try requireSessionID(), season: season))
    }

    func season() async throws -> AccountSeasonDocument {
        try unwrap(await transport.season(sessionID: try requireSessionID()))
    }

    @discardableResult
    func applySeasonChange(baseVersion: Int,
                           updatedBody: AppData,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String) async throws -> SeasonChangeReceipt {
        try unwrap(await transport.applySeasonChange(sessionID: try requireSessionID(),
                                                     baseVersion: baseVersion,
                                                     updatedBody: updatedBody,
                                                     domains: domains,
                                                     clientMutationID: clientMutationID))
    }

    func updateProfile(visibility: ProfileVisibility, searchable: Bool) async throws {
        _ = try unwrap(await transport.updateProfile(sessionID: try requireSessionID(),
                                                     visibility: visibility,
                                                     searchable: searchable))
    }

    func searchProfiles(query: String) async throws -> [AccountProfile] {
        try unwrap(await transport.searchProfiles(sessionID: try requireSessionID(), query: query))
    }

    @discardableResult
    func follow(targetID: String) async throws -> RelationshipEdge {
        try unwrap(await transport.follow(sessionID: try requireSessionID(), targetID: targetID))
    }

    func unfollow(targetID: String) async throws {
        _ = try unwrap(await transport.unfollow(sessionID: try requireSessionID(), targetID: targetID))
    }

    func block(targetID: String) async throws {
        _ = try unwrap(await transport.block(sessionID: try requireSessionID(), targetID: targetID))
    }

    @discardableResult
    func createSharedObject(kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility = .membersOnly) async throws -> SharedCurlingObject {
        try unwrap(await transport.createSharedObject(sessionID: try requireSessionID(),
                                                      kind: kind,
                                                      title: title,
                                                      visibility: visibility))
    }

    func addMember(objectID: String, accountID: String, role: MembershipRole) async throws {
        _ = try unwrap(await transport.addMember(sessionID: try requireSessionID(),
                                                 objectID: objectID,
                                                 accountID: accountID,
                                                 role: role))
    }

    func updateSharedObjectTitle(objectID: String, title: String) async throws {
        _ = try unwrap(await transport.updateSharedObjectTitle(sessionID: try requireSessionID(),
                                                               objectID: objectID,
                                                               title: title))
    }

    @discardableResult
    func createInteraction(objectID: String,
                           kind: InteractionKind,
                           body: String) async throws -> SocialInteraction {
        try unwrap(await transport.createInteraction(sessionID: try requireSessionID(),
                                                     objectID: objectID,
                                                     kind: kind,
                                                     body: body))
    }

    func deleteInteraction(interactionID: String) async throws {
        _ = try unwrap(await transport.deleteInteraction(sessionID: try requireSessionID(), interactionID: interactionID))
    }

    @discardableResult
    func reportInteraction(interactionID: String, reason: String) async throws -> ContentReport {
        try unwrap(await transport.reportInteraction(sessionID: try requireSessionID(),
                                                     interactionID: interactionID,
                                                     reason: reason))
    }

    func hideReportedInteraction(reportID: String) async throws {
        _ = try unwrap(await transport.hideReportedInteraction(reportID: reportID))
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
