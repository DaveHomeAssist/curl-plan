import Combine
import Foundation

enum AccountRuntimeKind: String, Equatable {
    case unconfigured
    case signedOut
    case working
    case signedIn
    case failed
}

struct AccountRuntimeState: Equatable {
    var kind: AccountRuntimeKind
    var title: String
    var detail: String
    var accountID: String?
    var exportSections: [String]
    var seasonVersion: Int?

    static let unconfigured = AccountRuntimeState(kind: .unconfigured,
                                                  title: "Local-only season",
                                                  detail: "This build is using local season data only. Export and import remain the recovery path.",
                                                  accountID: nil,
                                                  exportSections: [],
                                                  seasonVersion: nil)

    static func signedOut(accountID: String?) -> AccountRuntimeState {
        AccountRuntimeState(kind: .signedOut,
                            title: accountID == nil ? "No backend session" : "Signed out",
                            detail: accountID == nil ? "Create or sign in to this configured backend with your handle and password." : "Sign in with your handle and password to load this backend season or delete the account.",
                            accountID: accountID,
                            exportSections: [],
                            seasonVersion: nil)
    }

    static func working(_ detail: String, accountID: String?) -> AccountRuntimeState {
        AccountRuntimeState(kind: .working,
                            title: "Backend request running",
                            detail: detail,
                            accountID: accountID,
                            exportSections: [],
                            seasonVersion: nil)
    }

    static func signedIn(accountID: String,
                         sections: [String],
                         seasonVersion: Int?,
                         detail: String) -> AccountRuntimeState {
        AccountRuntimeState(kind: .signedIn,
                            title: "Backend session active",
                            detail: detail,
                            accountID: accountID,
                            exportSections: sections,
                            seasonVersion: seasonVersion)
    }

    static func failed(_ detail: String, accountID: String?) -> AccountRuntimeState {
        AccountRuntimeState(kind: .failed,
                            title: "Backend request failed",
                            detail: detail,
                            accountID: accountID,
                            exportSections: [],
                            seasonVersion: nil)
    }
}

struct AccountRuntimeResult: Equatable {
    var message: String
    var restoredSeason: AppData?
}

@MainActor
final class AccountRuntime: ObservableObject {
    nonisolated static let backendURLEnvironmentKey = "CURLPLAN_ACCOUNT_BACKEND_URL"
    nonisolated static let backendURLArgumentKey = "-curlplan-account-backend-url"
    nonisolated static let accountIDKey = "curlplan.account.backend.accountID"
    nonisolated static let handleKey = "curlplan.account.backend.handle"
    nonisolated static let deviceIDKey = "curlplan.account.backend.deviceID"

    @Published private(set) var state: AccountRuntimeState

    private let baseURL: URL?
    private let defaults: UserDefaults
    private let loader: AccountHTTPDataLoading
    private var client: AccountHTTPBackendClient?

    init(baseURL: URL? = AccountRuntime.resolveBackendURL(),
         defaults: UserDefaults = .standard,
         loader: AccountHTTPDataLoading = URLSession.shared) {
        self.baseURL = baseURL
        self.defaults = defaults
        self.loader = loader
        state = baseURL == nil ? .unconfigured : .signedOut(accountID: defaults.string(forKey: Self.accountIDKey))
    }

    var isConfigured: Bool { baseURL != nil }
    var isBusy: Bool { state.kind == .working }
    var isSignedIn: Bool { state.kind == .signedIn }
    var hasSavedAccount: Bool { defaults.string(forKey: Self.accountIDKey) != nil }
    var savedHandle: String? { defaults.string(forKey: Self.handleKey) }

    nonisolated static func resolveBackendURL(arguments: [String] = ProcessInfo.processInfo.arguments,
                                              environment: [String: String] = ProcessInfo.processInfo.environment,
                                              defaults: UserDefaults = .standard) -> URL? {
        if let raw = environment[backendURLEnvironmentKey], let url = URL(string: raw), url.scheme?.hasPrefix("http") == true {
            return url
        }
        if let index = arguments.firstIndex(of: backendURLArgumentKey),
           arguments.indices.contains(index + 1),
           let url = URL(string: arguments[index + 1]),
           url.scheme?.hasPrefix("http") == true {
            return url
        }
        if let raw = defaults.string(forKey: "curlplan.account.backendURL"),
           let url = URL(string: raw),
           url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }

    func createAccount(handle: String, password: String, season: AppData) async -> AccountRuntimeResult {
        guard isConfigured else { return unavailableResult() }
        let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        state = .working("Creating account, opening a backend session, and importing this local season.", accountID: savedAccountID)
        do {
            let client = try configuredClient()
            let account = try await client.createAccount(handle: normalizedHandle,
                                                         displayName: season.profile.name,
                                                         homeClub: season.profile.homeClub,
                                                         password: password)
            defaults.set(account.id, forKey: Self.accountIDKey)
            defaults.set(normalizedHandle, forKey: Self.handleKey)
            try await client.signIn(handle: normalizedHandle, password: password, deviceID: deviceID())
            let document = try await client.importLocalSeason(season)
            let sections = try await client.exportAccountData()
            let message = "Backend account \(shortID(account.id)) imported season version \(document.version)."
            state = .signedIn(accountID: account.id,
                              sections: sections,
                              seasonVersion: document.version,
                              detail: message)
            return AccountRuntimeResult(message: message, restoredSeason: nil)
        } catch {
            return fail(error, fallback: "Backend account creation failed.")
        }
    }

    func signIn(handle: String, password: String) async -> AccountRuntimeResult {
        guard isConfigured else { return unavailableResult() }
        let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        state = .working("Signing in and asking the backend for the account season.", accountID: savedAccountID)
        do {
            let client = try configuredClient()
            let session = try await client.signIn(handle: normalizedHandle, password: password, deviceID: deviceID())
            defaults.set(session.accountID, forKey: Self.accountIDKey)
            defaults.set(normalizedHandle, forKey: Self.handleKey)
            let document = try await fetchSeasonIfPresent(client)
            let sections = try await client.exportAccountData()
            let message: String
            if let document {
                message = "Backend season version \(document.version) restored from API."
            } else {
                message = "Signed in. No backend season exists yet for this account."
            }
            state = .signedIn(accountID: session.accountID,
                              sections: sections,
                              seasonVersion: document?.version,
                              detail: message)
            return AccountRuntimeResult(message: message, restoredSeason: document?.body)
        } catch {
            return fail(error, fallback: "Backend sign in failed.")
        }
    }

    func exportAccountData() async -> AccountRuntimeResult {
        guard isConfigured else { return unavailableResult() }
        state = .working("Requesting backend account export sections.", accountID: savedAccountID)
        do {
            let client = try requireSignedInClient()
            let sections = try await client.exportAccountData()
            let accountID = client.session?.accountID ?? savedAccountID ?? ""
            let message = "Backend export includes \(sections.joined(separator: ", "))."
            state = .signedIn(accountID: accountID,
                              sections: sections,
                              seasonVersion: state.seasonVersion,
                              detail: message)
            return AccountRuntimeResult(message: message, restoredSeason: nil)
        } catch {
            return fail(error, fallback: "Backend export failed.")
        }
    }

    func signOut() async -> AccountRuntimeResult {
        guard isConfigured else { return unavailableResult() }
        do {
            if let client, client.session != nil {
                try await client.signOut()
            }
            let message = "Backend session signed out. Local season data is unchanged."
            state = .signedOut(accountID: savedAccountID)
            return AccountRuntimeResult(message: message, restoredSeason: nil)
        } catch let error as AccountAPIError where error.code == "CLIENT_SIGNED_OUT" {
            state = .signedOut(accountID: savedAccountID)
            return AccountRuntimeResult(message: "No active backend session was stored on this device.", restoredSeason: nil)
        } catch {
            return fail(error, fallback: "Backend sign out failed.")
        }
    }

    func deleteAccount() async -> AccountRuntimeResult {
        guard isConfigured else { return unavailableResult() }
        state = .working("Asking the backend to delete this account and revoke its sessions.", accountID: savedAccountID)
        do {
            let client = try requireSignedInClient()
            try await client.deleteAccount()
            clearSavedAccount()
            state = .signedOut(accountID: nil)
            return AccountRuntimeResult(message: "Backend account deleted. Local season data is unchanged.", restoredSeason: nil)
        } catch let error as AccountAPIError where error.code == "ACCOUNT_DELETED" {
            clearSavedAccount()
            state = .signedOut(accountID: nil)
            return AccountRuntimeResult(message: "Backend already reports this account as deleted.", restoredSeason: nil)
        } catch {
            return fail(error, fallback: "Backend account deletion failed.")
        }
    }

    private var savedAccountID: String? {
        defaults.string(forKey: Self.accountIDKey)
    }

    private func configuredClient() throws -> AccountHTTPBackendClient {
        guard let baseURL else {
            throw AccountAPIError(status: 503,
                                  code: "BACKEND_UNCONFIGURED",
                                  message: "No account backend URL is configured.",
                                  requestID: "client")
        }
        if let client {
            return client
        }
        let next = AccountHTTPBackendClient(transport: AccountHTTPBackendTransport(baseURL: baseURL, loader: loader))
        client = next
        return next
    }

    private func requireSignedInClient() throws -> AccountHTTPBackendClient {
        let client = try configuredClient()
        guard client.session != nil else {
            throw AccountAPIError(status: 401,
                                  code: "CLIENT_SIGNED_OUT",
                                  message: "Sign in to your account before running this action.",
                                  requestID: "client")
        }
        return client
    }

    /// Fetches the account season, treating an absent season as a clean nil so a
    /// freshly created account on a new device signs in without surfacing an error.
    private func fetchSeasonIfPresent(_ client: AccountHTTPBackendClient) async throws -> AccountSeasonDocument? {
        do {
            return try await client.season()
        } catch let error as AccountAPIError where error.code == "SEASON_MISSING" || error.status == 404 {
            return nil
        }
    }

    private func clearSavedAccount() {
        defaults.removeObject(forKey: Self.accountIDKey)
        defaults.removeObject(forKey: Self.handleKey)
    }

    private func deviceID() -> String {
        if let existing = defaults.string(forKey: Self.deviceIDKey) {
            return existing
        }
        let next = "device-\(UUID().uuidString.lowercased())"
        defaults.set(next, forKey: Self.deviceIDKey)
        return next
    }

    private func unavailableResult() -> AccountRuntimeResult {
        state = .unconfigured
        return AccountRuntimeResult(message: AccountRuntimeState.unconfigured.detail, restoredSeason: nil)
    }

    private func fail(_ error: Error, fallback: String) -> AccountRuntimeResult {
        let message: String
        if let apiError = error as? AccountAPIError {
            message = "\(fallback) \(apiError.code): \(apiError.message)"
        } else {
            message = fallback
        }
        state = .failed(message, accountID: savedAccountID)
        return AccountRuntimeResult(message: message, restoredSeason: nil)
    }

    private func shortID(_ id: String) -> String {
        String(id.prefix(12))
    }
}
