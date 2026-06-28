import Foundation
import CryptoKit

/// Salted password credential. The deployable backend uses scrypt; this in-app
/// contract mirror uses salted SHA-256 so wrong passwords are rejected without
/// ever storing the plaintext. Both enforce the same auth boundary.
struct PasswordCredential: Equatable, Codable {
    var salt: String
    var hash: String
}

enum PasswordHasher {
    static let minimumLength = 8

    static func make(_ password: String, salt: String = UUID().uuidString) -> PasswordCredential {
        PasswordCredential(salt: salt, hash: digest(password: password, salt: salt))
    }

    static func verify(_ password: String, credential: PasswordCredential?) -> Bool {
        guard let credential else { return false }
        return digest(password: password, salt: credential.salt) == credential.hash
    }

    private static func digest(password: String, salt: String) -> String {
        let data = Data("\(salt):\(password)".utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum AccountStatus: String, Hashable, Codable {
    case active
    case suspended
    case deletionPending = "deletion_pending"
    case deleted
}

enum SessionState: String, Hashable, Codable {
    case active
    case revoked
    case expired
}

enum ProfileVisibility: String, Hashable, Codable {
    case privateProfile = "private"
    case publicProfile = "public"
}

enum RelationshipKind: String, Hashable, Codable {
    case follow
    case friendRequest = "friend_request"
    case teammate
    case block
    case invite
}

enum RelationshipState: String, Hashable, Codable {
    case pending
    case accepted
    case declined
    case revoked
}

enum SharedObjectKind: String, Hashable, Codable {
    case spiel
    case bonspiel
    case team
    case roster
    case lineup
    case scorecard
}

enum SharedVisibility: String, Hashable, Codable {
    case privateObject = "private"
    case membersOnly = "members_only"
    case publicObject = "public"
}

enum MembershipRole: String, Hashable, Codable {
    case owner
    case admin
    case teammate
    case viewer
}

enum InteractionKind: String, Hashable, Codable {
    case rsvp
    case invite
    case reaction
    case comment
    case message
}

enum InteractionState: String, Hashable, Codable {
    case active
    case edited
    case deleted
    case hiddenByModeration = "hidden_by_moderation"
}

enum ReportState: String, Hashable, Codable {
    case open
    case reviewed
    case actioned
    case dismissed
}

enum AccountBackendError: Error, Equatable {
    case accountDeleted
    case accountNotFound
    case invalidCredentials
    case weakPassword
    case handleTaken
    case sessionInvalid
    case seasonMissing
    case seasonAlreadyExists
    case versionConflict(currentVersion: Int)
    case blocked
    case privateProfile
    case notFound
    case notMember
    case insufficientRole
    case rateLimited
}

struct CurlPlanAccount: Identifiable, Hashable, Codable {
    var id: String
    var createdAt: String
    var status: AccountStatus
    var deletedAt: String?
}

struct AccountSession: Identifiable, Hashable, Codable {
    var id: String
    var accountID: String
    var deviceID: String
    var createdAt: String
    var expiresAt: String
    var state: SessionState
}

struct AccountProfile: Hashable, Codable {
    var accountID: String
    var handle: String
    var displayName: String
    var homeClub: String
    var avatarURL: String?
    var visibility: ProfileVisibility
    var searchable: Bool
}

struct AccountSeasonDocument: Identifiable, Hashable, Codable {
    var id: String
    var accountID: String
    var schemaVersion: Int
    var version: Int
    var body: AppData
    var updatedAt: String
}

struct SeasonChangeReceipt: Identifiable, Hashable, Codable {
    var id: String
    var seasonID: String
    var actorID: String
    var baseVersion: Int
    var serverVersion: Int
    var clientMutationID: String
    var domains: Set<SeasonDomain>
}

struct OfflineSeasonMutation: Identifiable, Hashable, Codable {
    var id: String
    var seasonID: String
    var baseVersion: Int
    var clientMutationID: String
    var domains: Set<SeasonDomain>
    var state: String
}

struct RelationshipEdge: Identifiable, Hashable, Codable {
    var id: String
    var actorID: String
    var targetID: String
    var kind: RelationshipKind
    var state: RelationshipState
    var createdAt: String
}

struct SharedCurlingObject: Identifiable, Hashable, Codable {
    var id: String
    var kind: SharedObjectKind
    var ownerID: String
    var visibility: SharedVisibility
    var version: Int
    var title: String
}

struct SharedMembership: Identifiable, Hashable, Codable {
    var id: String
    var objectID: String
    var accountID: String
    var role: MembershipRole
    var state: RelationshipState
}

struct SocialInteraction: Identifiable, Hashable, Codable {
    var id: String
    var objectID: String
    var actorID: String
    var kind: InteractionKind
    var body: String
    var state: InteractionState
    var createdAt: String
}

struct ContentReport: Identifiable, Hashable, Codable {
    var id: String
    var reporterID: String
    var targetID: String
    var reason: String
    var state: ReportState
    var createdAt: String
}

struct AccountSocialSnapshot: Equatable, Codable {
    var accounts: [String: CurlPlanAccount]
    var credentials: [String: PasswordCredential]
    var sessions: [String: AccountSession]
    var profiles: [String: AccountProfile]
    var seasons: [String: AccountSeasonDocument]
    var relationships: [RelationshipEdge]
    var sharedObjects: [String: SharedCurlingObject]
    var memberships: [SharedMembership]
    var interactions: [String: SocialInteraction]
    var reports: [ContentReport]
    var counter: Int

    static let empty = AccountSocialSnapshot(accounts: [:],
                                             credentials: [:],
                                             sessions: [:],
                                             profiles: [:],
                                             seasons: [:],
                                             relationships: [],
                                             sharedObjects: [:],
                                             memberships: [],
                                             interactions: [:],
                                             reports: [],
                                             counter: 0)
}

final class AccountSocialContractStore {
    private(set) var accounts: [String: CurlPlanAccount] = [:]
    private(set) var credentials: [String: PasswordCredential] = [:]
    private(set) var sessions: [String: AccountSession] = [:]
    private(set) var profiles: [String: AccountProfile] = [:]
    private(set) var seasons: [String: AccountSeasonDocument] = [:]
    private(set) var relationships: [RelationshipEdge] = []
    private(set) var sharedObjects: [String: SharedCurlingObject] = [:]
    private(set) var memberships: [SharedMembership] = []
    private(set) var interactions: [String: SocialInteraction] = [:]
    private(set) var reports: [ContentReport] = []

    private var counter = 0

    init(snapshot: AccountSocialSnapshot = .empty) {
        accounts = snapshot.accounts
        credentials = snapshot.credentials
        sessions = snapshot.sessions
        profiles = snapshot.profiles
        seasons = snapshot.seasons
        relationships = snapshot.relationships
        sharedObjects = snapshot.sharedObjects
        memberships = snapshot.memberships
        interactions = snapshot.interactions
        reports = snapshot.reports
        counter = snapshot.counter
    }

    func snapshot() -> AccountSocialSnapshot {
        AccountSocialSnapshot(accounts: accounts,
                              credentials: credentials,
                              sessions: sessions,
                              profiles: profiles,
                              seasons: seasons,
                              relationships: relationships,
                              sharedObjects: sharedObjects,
                              memberships: memberships,
                              interactions: interactions,
                              reports: reports,
                              counter: counter)
    }

    @discardableResult
    func createAccount(handle: String,
                       displayName: String,
                       homeClub: String,
                       password: String,
                       now: String = "now") throws -> CurlPlanAccount {
        guard password.count >= PasswordHasher.minimumLength else { throw AccountBackendError.weakPassword }
        let normalizedHandle = handle.lowercased()
        if profiles.values.contains(where: { $0.handle.lowercased() == normalizedHandle }) {
            throw AccountBackendError.handleTaken
        }
        let account = CurlPlanAccount(id: nextID("acct"),
                                      createdAt: now,
                                      status: .active,
                                      deletedAt: nil)
        accounts[account.id] = account
        credentials[account.id] = PasswordHasher.make(password)
        profiles[account.id] = AccountProfile(accountID: account.id,
                                              handle: handle,
                                              displayName: displayName,
                                              homeClub: homeClub,
                                              avatarURL: nil,
                                              visibility: .privateProfile,
                                              searchable: false)
        return account
    }

    func signIn(handle: String, password: String, deviceID: String, now: String = "now") throws -> AccountSession {
        let normalizedHandle = handle.lowercased()
        let accountID = profiles.values.first(where: { $0.handle.lowercased() == normalizedHandle })?.accountID
        let account = accountID.flatMap { accounts[$0] }
        // Generic failure so a wrong handle and a wrong password are indistinguishable.
        guard let accountID,
              let account,
              account.status != .deleted,
              PasswordHasher.verify(password, credential: credentials[accountID]) else {
            throw AccountBackendError.invalidCredentials
        }
        let session = AccountSession(id: nextID("sess"),
                                     accountID: accountID,
                                     deviceID: deviceID,
                                     createdAt: now,
                                     expiresAt: "later",
                                     state: .active)
        sessions[session.id] = session
        return session
    }

    func signOut(sessionID: String) {
        guard var session = sessions[sessionID] else { return }
        session.state = .revoked
        sessions[sessionID] = session
    }

    func deleteAccount(sessionID: String, now: String = "now") throws {
        let accountID = try requireAccount(sessionID: sessionID)
        guard var account = accounts[accountID] else { throw AccountBackendError.accountNotFound }
        account.status = .deleted
        account.deletedAt = now
        accounts[accountID] = account
        credentials.removeValue(forKey: accountID)
        profiles.removeValue(forKey: accountID)
        seasons.removeValue(forKey: accountID)
        sessions = sessions.mapValues { session in
            var revoked = session
            if session.accountID == accountID {
                revoked.state = .revoked
            }
            return revoked
        }
        relationships.removeAll { $0.actorID == accountID || $0.targetID == accountID }
        memberships.removeAll { $0.accountID == accountID }
        interactions = interactions.filter { $0.value.actorID != accountID }
    }

    func exportAccountData(sessionID: String) throws -> [String] {
        let accountID = try requireAccount(sessionID: sessionID)
        var sections = ["account", "profile"]
        if seasons[accountID] != nil {
            sections.append("season")
        }
        if sharedObjects.values.contains(where: { $0.ownerID == accountID }) {
            sections.append("owned_shared_objects")
        }
        return sections
    }

    @discardableResult
    func importLocalSeason(sessionID: String, season: AppData, now: String = "now") throws -> AccountSeasonDocument {
        let accountID = try requireAccount(sessionID: sessionID)
        if seasons[accountID] != nil {
            throw AccountBackendError.seasonAlreadyExists
        }
        let document = AccountSeasonDocument(id: nextID("season"),
                                             accountID: accountID,
                                             schemaVersion: season.schemaVersion,
                                             version: 1,
                                             body: season,
                                             updatedAt: now)
        seasons[accountID] = document
        return document
    }

    func season(sessionID: String) throws -> AccountSeasonDocument {
        let accountID = try requireAccount(sessionID: sessionID)
        guard let season = seasons[accountID] else { throw AccountBackendError.seasonMissing }
        return season
    }

    @discardableResult
    func applySeasonChange(sessionID: String,
                           baseVersion: Int,
                           updatedBody: AppData,
                           domains: Set<SeasonDomain>,
                           clientMutationID: String,
                           now: String = "now") throws -> SeasonChangeReceipt {
        let accountID = try requireAccount(sessionID: sessionID)
        guard var document = seasons[accountID] else { throw AccountBackendError.seasonMissing }
        guard document.version == baseVersion else {
            throw AccountBackendError.versionConflict(currentVersion: document.version)
        }
        document.version += 1
        document.body = updatedBody
        document.updatedAt = now
        seasons[accountID] = document
        return SeasonChangeReceipt(id: nextID("change"),
                                   seasonID: document.id,
                                   actorID: accountID,
                                   baseVersion: baseVersion,
                                   serverVersion: document.version,
                                   clientMutationID: clientMutationID,
                                   domains: domains)
    }

    func updateProfile(sessionID: String,
                       visibility: ProfileVisibility,
                       searchable: Bool) throws {
        let accountID = try requireAccount(sessionID: sessionID)
        guard var profile = profiles[accountID] else { throw AccountBackendError.accountNotFound }
        profile.visibility = visibility
        profile.searchable = searchable
        profiles[accountID] = profile
    }

    func searchProfiles(sessionID: String, query: String) throws -> [AccountProfile] {
        let actorID = try requireAccount(sessionID: sessionID)
        let lowerQuery = query.lowercased()
        return profiles.values
            .filter { profile in
                profile.visibility == .publicProfile &&
                profile.searchable &&
                !isBlocked(between: actorID, and: profile.accountID) &&
                (profile.handle.lowercased().contains(lowerQuery) || profile.displayName.lowercased().contains(lowerQuery))
            }
            .sorted { $0.handle < $1.handle }
    }

    @discardableResult
    func follow(sessionID: String, targetID: String) throws -> RelationshipEdge {
        let actorID = try requireAccount(sessionID: sessionID)
        guard accounts[targetID]?.status == .active else { throw AccountBackendError.accountNotFound }
        guard !isBlocked(between: actorID, and: targetID) else { throw AccountBackendError.blocked }
        if let existing = relationships.first(where: { $0.actorID == actorID && $0.targetID == targetID && $0.kind == .follow }) {
            return existing
        }
        let edge = RelationshipEdge(id: nextID("rel"),
                                    actorID: actorID,
                                    targetID: targetID,
                                    kind: .follow,
                                    state: .accepted,
                                    createdAt: "now")
        relationships.append(edge)
        return edge
    }

    func unfollow(sessionID: String, targetID: String) throws {
        let actorID = try requireAccount(sessionID: sessionID)
        relationships.removeAll { $0.actorID == actorID && $0.targetID == targetID && $0.kind == .follow }
    }

    func block(sessionID: String, targetID: String) throws {
        let actorID = try requireAccount(sessionID: sessionID)
        guard accounts[targetID] != nil else { throw AccountBackendError.accountNotFound }
        relationships.removeAll { ($0.actorID == actorID && $0.targetID == targetID) || ($0.actorID == targetID && $0.targetID == actorID) }
        relationships.append(RelationshipEdge(id: nextID("rel"),
                                              actorID: actorID,
                                              targetID: targetID,
                                              kind: .block,
                                              state: .accepted,
                                              createdAt: "now"))
    }

    @discardableResult
    func createSharedObject(sessionID: String,
                            kind: SharedObjectKind,
                            title: String,
                            visibility: SharedVisibility = .membersOnly) throws -> SharedCurlingObject {
        let ownerID = try requireAccount(sessionID: sessionID)
        let object = SharedCurlingObject(id: nextID("obj"),
                                         kind: kind,
                                         ownerID: ownerID,
                                         visibility: visibility,
                                         version: 1,
                                         title: title)
        sharedObjects[object.id] = object
        memberships.append(SharedMembership(id: nextID("member"),
                                            objectID: object.id,
                                            accountID: ownerID,
                                            role: .owner,
                                            state: .accepted))
        return object
    }

    func addMember(sessionID: String,
                   objectID: String,
                   accountID: String,
                   role: MembershipRole) throws {
        let actorID = try requireAccount(sessionID: sessionID)
        guard canAdministerObject(accountID: actorID, objectID: objectID) else { throw AccountBackendError.insufficientRole }
        guard !isBlocked(between: actorID, and: accountID) else { throw AccountBackendError.blocked }
        memberships.append(SharedMembership(id: nextID("member"),
                                            objectID: objectID,
                                            accountID: accountID,
                                            role: role,
                                            state: .accepted))
    }

    func updateSharedObjectTitle(sessionID: String, objectID: String, title: String) throws {
        let actorID = try requireAccount(sessionID: sessionID)
        guard canEditObject(accountID: actorID, objectID: objectID) else { throw AccountBackendError.insufficientRole }
        guard var object = sharedObjects[objectID] else { throw AccountBackendError.notFound }
        object.title = title
        object.version += 1
        sharedObjects[objectID] = object
    }

    @discardableResult
    func createInteraction(sessionID: String,
                           objectID: String,
                           kind: InteractionKind,
                           body: String) throws -> SocialInteraction {
        let actorID = try requireAccount(sessionID: sessionID)
        guard canReadObject(accountID: actorID, objectID: objectID) else { throw AccountBackendError.notMember }
        let existingCount = interactions.values.filter { $0.actorID == actorID && $0.objectID == objectID && $0.state == .active }.count
        guard existingCount < 10 else { throw AccountBackendError.rateLimited }
        let interaction = SocialInteraction(id: nextID("int"),
                                            objectID: objectID,
                                            actorID: actorID,
                                            kind: kind,
                                            body: body,
                                            state: .active,
                                            createdAt: "now")
        interactions[interaction.id] = interaction
        return interaction
    }

    func deleteInteraction(sessionID: String, interactionID: String) throws {
        let actorID = try requireAccount(sessionID: sessionID)
        guard var interaction = interactions[interactionID] else { throw AccountBackendError.notFound }
        guard interaction.actorID == actorID else { throw AccountBackendError.insufficientRole }
        interaction.state = .deleted
        interactions[interactionID] = interaction
    }

    @discardableResult
    func reportInteraction(sessionID: String,
                           interactionID: String,
                           reason: String) throws -> ContentReport {
        let reporterID = try requireAccount(sessionID: sessionID)
        guard interactions[interactionID] != nil else { throw AccountBackendError.notFound }
        let report = ContentReport(id: nextID("report"),
                                   reporterID: reporterID,
                                   targetID: interactionID,
                                   reason: reason,
                                   state: .open,
                                   createdAt: "now")
        reports.append(report)
        return report
    }

    func hideReportedInteraction(reportID: String) throws {
        guard let report = reports.first(where: { $0.id == reportID }) else { throw AccountBackendError.notFound }
        guard var interaction = interactions[report.targetID] else { throw AccountBackendError.notFound }
        interaction.state = .hiddenByModeration
        interactions[interaction.id] = interaction
        reports = reports.map { item in
            if item.id == reportID {
                var updated = item
                updated.state = .actioned
                return updated
            }
            return item
        }
    }

    private func requireAccount(sessionID: String) throws -> String {
        guard let session = sessions[sessionID], session.state == .active else {
            throw AccountBackendError.sessionInvalid
        }
        guard let account = accounts[session.accountID] else {
            throw AccountBackendError.accountNotFound
        }
        guard account.status != .deleted else {
            throw AccountBackendError.accountDeleted
        }
        return account.id
    }

    private func isBlocked(between first: String, and second: String) -> Bool {
        relationships.contains {
            $0.kind == .block &&
            $0.state == .accepted &&
            (($0.actorID == first && $0.targetID == second) || ($0.actorID == second && $0.targetID == first))
        }
    }

    private func canReadObject(accountID: String, objectID: String) -> Bool {
        guard let object = sharedObjects[objectID] else { return false }
        if object.visibility == .publicObject { return true }
        return memberships.contains { $0.objectID == objectID && $0.accountID == accountID && $0.state == .accepted }
    }

    private func canAdministerObject(accountID: String, objectID: String) -> Bool {
        memberships.contains {
            $0.objectID == objectID &&
            $0.accountID == accountID &&
            $0.state == .accepted &&
            ($0.role == .owner || $0.role == .admin)
        }
    }

    private func canEditObject(accountID: String, objectID: String) -> Bool {
        memberships.contains {
            $0.objectID == objectID &&
            $0.accountID == accountID &&
            $0.state == .accepted &&
            ($0.role == .owner || $0.role == .admin || $0.role == .teammate)
        }
    }

    private func nextID(_ prefix: String) -> String {
        counter += 1
        return "\(prefix)-\(counter)"
    }
}
