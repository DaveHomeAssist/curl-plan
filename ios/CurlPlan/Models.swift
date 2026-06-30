import Combine
import Foundation

// MARK: - Models

struct GameLine: Identifiable, Hashable, Codable {
    var id = UUID()
    let label: String   // opponent or game label
    let score: String   // "8-4"
    let res: String     // "W" / "L"
}

struct PlayerProfile: Hashable, Codable {
    var name: String
    var initials: String
    var homeClub: String
    var homeProvince: String
    var season: String
    var demoMode: Bool
    var baseGames: Int
    var baseWins: Int

    var importedGameCount: Int { baseGames }
    var importedWinCount: Int { baseWins }

    static let demo = PlayerProfile(name: "Dana Mercer",
                                    initials: "DM",
                                    homeClub: "Calgary Granite CC",
                                    homeProvince: "AB",
                                    season: "Season 2025-26 · demo season",
                                    demoMode: true,
                                    baseGames: 38,
                                    baseWins: 26)

    static func blank(name: String, homeClub: String, province: String) -> PlayerProfile {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initials = cleanName.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
        return PlayerProfile(name: cleanName.isEmpty ? "CurlPlan User" : cleanName,
                             initials: initials.isEmpty ? "CP" : initials,
                             homeClub: homeClub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Home rink TBD" : homeClub,
                             homeProvince: province.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TBD" : province.uppercased(),
                             season: "Season 2025-26 · blank season",
                             demoMode: false,
                             baseGames: 0,
                             baseWins: 0)
    }
}

struct SeasonSummary {
    let rinks: Int
    let provinces: Int
    let games: Int
    let winPercent: Int
    let wins: Int
    let met: Int
    let kilometers: Int
    let distanceLabel: String
}

struct CurlerProfileSummary: Hashable {
    var curler: Curler
    var record: String
    var win: String
    var rinks: Int
    var mutual: Int
    var sharedRinks: [String]
    var recentForm: [GameLine]

    var shareText: String {
        "\(curler.name), \(curler.role), \(curler.club) (\(curler.prov)). Record \(record), win \(win)."
    }
}

struct ImportedCurlerHistory: Hashable, Codable {
    var record: String
    var win: String
    var rinks: Int
    var mutual: Int
    var sharedRinks: [String]
    var form: [GameLine]
}

struct Curler: Identifiable, Hashable, Codable {
    let id: String
    let initials: String
    let name: String
    let role: String
    let club: String
    let prov: String
    let metAt: String
    var following: Bool
    let record: String
    let win: String
    let rinks: Int
    let mutual: Int
    let sharedRinks: [String]
    let form: [GameLine]
    var importedHistory: ImportedCurlerHistory? = nil
}

struct Stop: Identifiable, Hashable, Codable {
    let id: String
    let code: String
    let name: String
    let club: String
    let prov: String
    let dates: String
    var record: String
    var here: Bool = false
    let x: Double           // 0–100 % position on the season map
    let y: Double
    var big: Bool = false
    var plus: String? = nil // "+3" badge on the avatar stack
    let iceSpeed: String
    let iceSpeedSec: String
    let iceCurl: String
    let iceRec: String
    var games: [GameLine]
    var met: [String]       // curler ids
    var latitude: Double? = nil
    var longitude: Double? = nil
}

struct ResultPost: Identifiable, Hashable, Codable {
    var id = UUID()
    let author: String, time: String, body: String
    let scoreFor: Int, scoreAgainst: Int, res: String, vs: String
}

struct SpielPost: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String, spielName: String, whereText: String, whenText: String
    let who: [String]
}

struct ReviewPost: Identifiable, Hashable, Codable {
    var id = UUID()
    let author: String, time: String, rink: String
    let stars: Int, note: String
}

enum FeedItem: Identifiable, Hashable, Codable {
    case result(ResultPost)
    case spiel(SpielPost)
    case review(ReviewPost)

    var id: UUID {
        switch self {
        case .result(let p): return p.id
        case .spiel(let p): return p.id
        case .review(let p): return p.id
        }
    }
}

struct Spiel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let whereText: String
    let whenText: String
    var status: String
    var going: [String]
    var startDate: String? = nil
    var endDate: String? = nil
    var stopID: String? = nil
}

struct GameResult: Identifiable, Hashable, Codable {
    var id = UUID()
    var authorID: String?
    var createdAt: String
    var note: String
    var opponent: String
    var scoreFor: Int
    var scoreAgainst: Int
    var stopID: String?
    var spielID: String?
    var participantCurlerIDs: [String]
    var ends: [BonspielEndScore]
    var conceded: Bool
    var forfeited: Bool
    var locallyConfirmed: Bool
    var bonspielID: String? = nil
    var bonspielGameID: String? = nil

    var res: String {
        if forfeited { return "FORFEIT" }
        if scoreFor == scoreAgainst { return "TIE" }
        return scoreFor > scoreAgainst ? "WIN" : "LOSS"
    }

    var scoreLabel: String {
        if ends.isEmpty {
            return "\(scoreFor)-\(scoreAgainst)"
        }
        let forTotal = ends.reduce(0) { $0 + $1.teamA }
        let againstTotal = ends.reduce(0) { $0 + $1.teamB }
        return "\(forTotal)-\(againstTotal)"
    }

    func asFeedPost(profile: PlayerProfile) -> ResultPost {
        let opponentLabel = opponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let vsLabel = opponentLabel.isEmpty ? "" : (opponentLabel.lowercased().hasPrefix("vs") ? opponentLabel : "vs \(opponentLabel)")
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = cleanNote.isEmpty ? "\(res.capitalized) \(scoreLabel) \(vsLabel).".trimmingCharacters(in: .whitespacesAndNewlines) : cleanNote
        return ResultPost(id: id,
                          author: authorID ?? "me",
                          time: createdAt,
                          body: body,
                          scoreFor: scoreFor,
                          scoreAgainst: scoreAgainst,
                          res: res,
                          vs: vsLabel)
    }
}

struct StopVisit: Identifiable, Hashable, Codable {
    var id = UUID()
    var stopID: String
    var arrivedAt: String
    var departedAt: String?
    var curlerIDs: [String]
    var note: String

    var isActive: Bool { departedAt == nil }
}

enum SpielAttendanceStatus: String, Hashable, Codable {
    case going
    case notGoing = "not_going"
}

struct SpielAttendance: Identifiable, Hashable, Codable {
    var id = UUID()
    var spielID: String
    var curlerID: String
    var status: SpielAttendanceStatus
    var updatedAt: String
}

enum SeasonDomain: String, Hashable, Codable {
    case setup
    case profile
    case curlers
    case stops
    case visits
    case spiels
    case attendance
    case results
    case feed
    case bonspiels
}

struct UndoToken: Hashable, Codable {
    var action: String
    var payloadID: String
}

struct MutationReceipt: Hashable, Codable {
    var id = UUID()
    var action: String
    var changedDomains: Set<SeasonDomain>
    var userMessage: String
    var focusRoute: Route?
    var undoToken: UndoToken?
}

enum CurlingDiscipline: String, CaseIterable, Hashable, Codable {
    case fourPlayer = "four_player"
    case mixed = "mixed"
    case mixedDoubles = "mixed_doubles"
    case wheelchair = "wheelchair"
    case wheelchairMixedDoubles = "wheelchair_mixed_doubles"
    case stick = "stick"
    case other = "other"

    var label: String {
        switch self {
        case .fourPlayer: return "Four player"
        case .mixed: return "Mixed"
        case .mixedDoubles: return "Mixed doubles"
        case .wheelchair: return "Wheelchair"
        case .wheelchairMixedDoubles: return "Wheelchair mixed doubles"
        case .stick: return "Stick"
        case .other: return "Other"
        }
    }

    var scheduledEnds: Int {
        switch self {
        case .mixedDoubles: return 8
        case .wheelchairMixedDoubles: return 8
        default: return 8
        }
    }

    var maxPlayersOnIce: Int {
        switch self {
        case .mixedDoubles, .wheelchairMixedDoubles: return 2
        default: return 4
        }
    }

    var allowsAlternates: Bool {
        switch self {
        case .mixed, .mixedDoubles, .wheelchairMixedDoubles: return false
        default: return true
        }
    }

    static func fromLabel(_ label: String) -> CurlingDiscipline {
        allCases.first { $0.label == label } ?? .fourPlayer
    }
}

enum BonspielGameStatus: String, Hashable, Codable {
    case scheduled
    case readyForLineup = "ready_for_lineup"
    case lineupLocked = "lineup_locked"
    case inProgress = "in_progress"
    case complete
    case finalized
    case forfeit
    case cancelled
    case postponed

    var label: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .readyForLineup: return "Ready for lineup"
        case .lineupLocked: return "Lineup locked"
        case .inProgress: return "In progress"
        case .complete: return "Complete"
        case .finalized: return "Finalized"
        case .forfeit: return "Forfeit"
        case .cancelled: return "Cancelled"
        case .postponed: return "Postponed"
        }
    }
}

struct BonspielVenue: Hashable, Codable {
    var name: String
    var city: String
    var region: String
    var country: String

    var display: String {
        [city, region].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    static func fromFreeText(_ text: String) -> BonspielVenue {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return BonspielVenue(name: "Venue TBD", city: "TBD", region: "", country: "CA")
        }
        let parts = clean
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return BonspielVenue(name: clean,
                             city: parts.first ?? clean,
                             region: parts.dropFirst().first ?? "",
                             country: "CA")
    }
}

struct BonspielWindow: Hashable, Codable {
    var opensAt: String
    var closesAt: String
}

struct BonspielRulesProfile: Hashable, Codable {
    var rulebookRef: String
    var scheduledEnds: Int
    var minEndsForLocalResult: Int
    var lsfeMethod: String
    var tiebreakerMethods: [String]
}

struct BonspielRosterPolicy: Hashable, Codable {
    var maxPlayersOnIce: Int
    var allowAlternates: Bool
    var allowSpares: Bool
    var allowReentry: Bool
    var lockMinutesBeforeGame: Int
}

struct BonspielPrivacyPolicy: Hashable, Codable {
    var rosterDisplayFields: [String]
    var internalFields: [String]
    var mediaConsentRequired: Bool
    var consentVersion: String
}

struct BonspielStage: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var stageType: String
    var sequence: Int
}

struct BonspielTeamMember: Identifiable, Hashable, Codable {
    var id: String
    var curlerID: String?
    var displayName: String
    var role: String
    var rosterStatus: String
    var declaredPosition: String
}

struct BonspielTeam: Identifiable, Hashable, Codable {
    var id: String
    var displayName: String
    var shortName: String
    var affiliation: String
    var members: [BonspielTeamMember]
}

struct BonspielLineupSlot: Hashable, Codable {
    var memberID: String
    var position: String
    var isSkip: Bool
    var isViceSkip: Bool
}

struct BonspielGameLineup: Identifiable, Hashable, Codable {
    var id: String
    var teamID: String
    var submittedAt: String
    var source: String
    var deliveryRotation: [BonspielLineupSlot]
    var alternateMemberID: String?
    var coachName: String?
}

struct BonspielLineupChange: Identifiable, Hashable, Codable {
    var id: String
    var teamID: String
    var outgoingMemberID: String?
    var incomingName: String
    var effectiveEnd: Int
    var reason: String
    var approvedBy: String
}

struct BonspielEndScore: Identifiable, Hashable, Codable {
    var id: String
    var endNumber: Int
    var teamA: Int
    var teamB: Int
    var hammerTeamIDStart: String?
    var isBlank: Bool
    var isExtraEnd: Bool
    var measureRequired: Bool
    var powerPlayUsed: Bool
}

struct BonspielLastStoneDecision: Hashable, Codable {
    var method: String
    var teamID: String
    var evidence: String
}

struct BonspielResultFlags: Hashable, Codable {
    var isFinal: Bool
    var conceded: Bool
    var forfeited: Bool
}

struct BonspielScoreAgreement: Hashable, Codable {
    var confirmed: Bool
    var confirmedAt: String?
    var confirmedBy: String?
}

struct BonspielGame: Identifiable, Hashable, Codable {
    var id: String
    var stageID: String
    var drawLabel: String
    var status: BonspielGameStatus
    var scheduledStartAt: String
    var sheet: String
    var teamAID: String
    var teamBID: String
    var stoneColorAssignment: String
    var lsfeOrPlacementDecision: BonspielLastStoneDecision
    var scheduledEnds: Int
    var minEndsForLocalResult: Int
    var ends: [BonspielEndScore]
    var gameLineups: [BonspielGameLineup]
    var lineupChanges: [BonspielLineupChange]
    var resultFlags: BonspielResultFlags
    var scoreAgreement: BonspielScoreAgreement
    var version: Int

    var completedEnds: Int {
        ends.filter { $0.teamA > 0 || $0.teamB > 0 || $0.isBlank }.count
    }

    var teamATotal: Int {
        ends.reduce(0) { $0 + $1.teamA }
    }

    var teamBTotal: Int {
        ends.reduce(0) { $0 + $1.teamB }
    }

    var scoreLabel: String {
        "\(teamATotal)-\(teamBTotal)"
    }
}

struct BonspielRecord: Identifiable, Hashable, Codable {
    var id: String
    var linkedSpielID: String
    var name: String
    var shortName: String
    var season: String
    var discipline: CurlingDiscipline
    var venue: BonspielVenue
    var timezone: String
    var startDate: String
    var endDate: String
    var registrationWindow: BonspielWindow
    var rulesProfile: BonspielRulesProfile
    var rosterPolicy: BonspielRosterPolicy
    var privacyPolicy: BonspielPrivacyPolicy
    var stages: [BonspielStage]
    var teams: [BonspielTeam]
    var games: [BonspielGame]
    var version: Int

    static func defaultLinked(spielID: String,
                              name: String,
                              whereText: String,
                              whenText: String,
                              discipline: CurlingDiscipline,
                              homeClub: String,
                              startDate: String? = nil,
                              endDate: String? = nil,
                              venue resolvedVenue: BonspielVenue? = nil,
                              timezone resolvedTimezone: String? = nil) -> BonspielRecord {
        let id = "bon-\(spielID)"
        let venue = resolvedVenue ?? BonspielVenue.fromFreeText(whereText)
        let canonicalStart = startDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalEnd = endDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackDate = whenText.isEmpty ? "Date TBD" : whenText
        return BonspielRecord(
            id: id,
            linkedSpielID: spielID,
            name: name,
            shortName: String(name.prefix(22)),
            season: "2025-26",
            discipline: discipline,
            venue: venue,
            timezone: resolvedTimezone ?? "America/Vancouver",
            startDate: (canonicalStart?.isEmpty == false ? canonicalStart : nil) ?? fallbackDate,
            endDate: (canonicalEnd?.isEmpty == false ? canonicalEnd : nil) ?? fallbackDate,
            registrationWindow: BonspielWindow(opensAt: "Open", closesAt: "Before draw"),
            rulesProfile: BonspielRulesProfile(rulebookRef: "Club rules profile",
                                                scheduledEnds: discipline.scheduledEnds,
                                                minEndsForLocalResult: min(6, discipline.scheduledEnds),
                                                lsfeMethod: "LSD or organizer decision",
                                                tiebreakerMethods: ["Win loss", "Head to head", "Draw shot challenge"]),
            rosterPolicy: BonspielRosterPolicy(maxPlayersOnIce: discipline.maxPlayersOnIce,
                                                allowAlternates: discipline.allowsAlternates,
                                                allowSpares: true,
                                                allowReentry: false,
                                                lockMinutesBeforeGame: 45),
            privacyPolicy: BonspielPrivacyPolicy(rosterDisplayFields: ["Team", "Name", "Position", "Club"],
                                                  internalFields: ["Birth date", "Email", "Phone", "Consent"],
                                                  mediaConsentRequired: false,
                                                  consentVersion: "v1"),
            stages: [BonspielStage(id: "\(id)-pool", name: "Pool", stageType: "round_robin", sequence: 1)],
            teams: [BonspielTeam(id: "\(id)-team-me",
                                  displayName: "Team \(homeClub.isEmpty ? "CurlPlan" : homeClub)",
                                  shortName: "Team CP",
                                  affiliation: homeClub.isEmpty ? "Home club TBD" : homeClub,
                                  members: [])],
            games: [],
            version: 1
        )
    }

    func teamName(_ teamID: String) -> String {
        teams.first(where: { $0.id == teamID })?.displayName ?? "Team TBD"
    }

    func memberName(_ memberID: String, teamID: String) -> String {
        teams.first(where: { $0.id == teamID })?
            .members.first(where: { $0.id == memberID })?
            .displayName ?? "Player TBD"
    }

    func lineupNames(_ lineup: BonspielGameLineup) -> [String] {
        lineup.deliveryRotation.map { slot in
            let name = memberName(slot.memberID, teamID: lineup.teamID)
            if slot.isSkip { return "\(slot.position) \(name) skip" }
            if slot.isViceSkip { return "\(slot.position) \(name) vice" }
            return "\(slot.position) \(name)"
        }
    }
}

struct AppData: Hashable, Codable {
    var schemaVersion: Int
    var setupComplete: Bool
    var profile: PlayerProfile
    var curlers: [Curler]
    var stops: [Stop]
    var visits: [StopVisit]
    var spiels: [Spiel]
    var attendance: [SpielAttendance]
    var results: [GameResult]
    var feed: [FeedItem]
    var bonspiels: [BonspielRecord]

    init(schemaVersion: Int,
         setupComplete: Bool,
         profile: PlayerProfile,
         curlers: [Curler],
         stops: [Stop],
         visits: [StopVisit],
         spiels: [Spiel],
         attendance: [SpielAttendance],
         results: [GameResult],
         feed: [FeedItem],
         bonspiels: [BonspielRecord]) {
        self.schemaVersion = schemaVersion
        self.setupComplete = setupComplete
        self.profile = profile
        self.curlers = curlers
        self.stops = stops
        self.visits = visits
        self.spiels = spiels
        self.attendance = attendance
        self.results = results
        self.feed = feed
        self.bonspiels = bonspiels
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case setupComplete
        case profile
        case curlers
        case stops
        case visits
        case spiels
        case attendance
        case results
        case feed
        case bonspiels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        setupComplete = try container.decodeIfPresent(Bool.self, forKey: .setupComplete) ?? true
        profile = try container.decode(PlayerProfile.self, forKey: .profile)
        curlers = try container.decodeIfPresent([Curler].self, forKey: .curlers) ?? []
        stops = try container.decodeIfPresent([Stop].self, forKey: .stops) ?? []
        visits = try container.decodeIfPresent([StopVisit].self, forKey: .visits) ?? []
        spiels = try container.decodeIfPresent([Spiel].self, forKey: .spiels) ?? []
        attendance = try container.decodeIfPresent([SpielAttendance].self, forKey: .attendance) ?? []
        results = try container.decodeIfPresent([GameResult].self, forKey: .results) ?? []
        feed = try container.decodeIfPresent([FeedItem].self, forKey: .feed) ?? []
        bonspiels = try container.decodeIfPresent([BonspielRecord].self, forKey: .bonspiels) ?? []
    }
}

enum StoreDataError: LocalizedError {
    case invalidJSON
    case unsupportedVersion(Int)
    case emptyProfile

    var errorDescription: String? {
        switch self {
        case .invalidJSON: return "That does not look like a CurlPlan season export."
        case .unsupportedVersion(let version): return "CurlPlan cannot import schema version \(version)."
        case .emptyProfile: return "The imported season is missing a player profile."
        }
    }
}

// Navigation routes for the per-tab NavigationStacks.
enum Route: Hashable, Codable {
    case stop(String)
    case curler(String)
}

private struct SpielRouteLocation {
    let code: String
    let city: String
    let region: String
    let club: String
    let latitude: Double
    let longitude: Double
    let seasonMapX: Double
    let seasonMapY: Double
    let timezone: String

    var venue: BonspielVenue {
        BonspielVenue(name: club, city: city, region: region, country: "CA")
    }

    func stop(spielID: String, name: String, dateText: String) -> Stop {
        Stop(id: "stop-\(spielID)",
             code: code,
             name: name,
             club: club,
             prov: region,
             dates: dateText,
             record: "—",
             here: false,
             x: seasonMapX,
             y: seasonMapY,
             big: false,
             plus: nil,
             iceSpeed: "—",
             iceSpeedSec: "—",
             iceCurl: "—",
             iceRec: "—",
             games: [],
             met: [],
             latitude: latitude,
             longitude: longitude)
    }

    static func resolve(_ freeText: String) -> SpielRouteLocation? {
        let normalized = freeText
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: " ")
        return known.first { place in
            place.matchTerms.contains { normalized.contains($0) }
        }?.location
    }

    private static let known: [(matchTerms: [String], location: SpielRouteLocation)] = [
        (["kamloops", "kamloops curling club"],
         SpielRouteLocation(code: "KAM",
                            city: "Kamloops",
                            region: "BC",
                            club: "Kamloops Curling Club",
                            latitude: 50.6745,
                            longitude: -120.3273,
                            seasonMapX: 86,
                            seasonMapY: 54,
                            timezone: "America/Vancouver")),
        (["kelowna", "kelowna curling club"],
         SpielRouteLocation(code: "KEL",
                            city: "Kelowna",
                            region: "BC",
                            club: "Kelowna Curling Club",
                            latitude: 49.8880,
                            longitude: -119.4960,
                            seasonMapX: 70,
                            seasonMapY: 32,
                            timezone: "America/Vancouver")),
        (["vernon", "vernon curling club"],
         SpielRouteLocation(code: "VER",
                            city: "Vernon",
                            region: "BC",
                            club: "Vernon Curling Club",
                            latitude: 50.2670,
                            longitude: -119.2720,
                            seasonMapX: 50,
                            seasonMapY: 68,
                            timezone: "America/Vancouver")),
        (["calgary", "sage valley", "calgary granite"],
         SpielRouteLocation(code: "CAL",
                            city: "Calgary",
                            region: "AB",
                            club: "Calgary Granite CC",
                            latitude: 51.0447,
                            longitude: -114.0719,
                            seasonMapX: 30,
                            seasonMapY: 39,
                            timezone: "America/Edmonton")),
        (["winnipeg", "granite city"],
         SpielRouteLocation(code: "WPG",
                            city: "Winnipeg",
                            region: "MB",
                            club: "Granite City CC",
                            latitude: 49.8951,
                            longitude: -97.1384,
                            seasonMapX: 14,
                            seasonMapY: 64,
                            timezone: "America/Winnipeg"))
    ]
}

// MARK: - Persistence

enum Persist {
    static let appDataKey = "cp.appdata.v2"
    static let curlersKey = "cp.curlers.v1"
    static let spielsKey = "cp.spiels.v1"
    static let feedKey = "cp.feed.v1"

    static func save<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func has(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    static func clearAllSeasonData() {
        [appDataKey, curlersKey, spielsKey, feedKey].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }
}

// MARK: - Store

final class Store: ObservableObject {
    @Published private var data: AppData = Seed.appData(setupComplete: false) {
        didSet { persistAll() }
    }

    private var isHydrating = false
    private var undoSnapshots: [String: AppData] = [:]

    init(appData: AppData? = nil, loadPersisted: Bool = true) {
        isHydrating = true
        if let appData {
            data = Self.normalized(appData)
        } else if loadPersisted, let saved: AppData = Persist.load(Persist.appDataKey) {
            data = Self.normalized(saved)
        } else if loadPersisted, Persist.has(Persist.curlersKey) || Persist.has(Persist.spielsKey) || Persist.has(Persist.feedKey) {
            data = Self.normalized(Self.legacyAppData())
        } else {
            data = Seed.appData(setupComplete: false)
        }
        isHydrating = false
    }

    struct Me {
        let name: String
        let initials: String
        let season: String
        let rinks: Int
        let prov: Int
        let games: Int
        let win: Int
    }

    var me: Me {
        let summary = seasonSummary
        return Me(name: data.profile.name,
                  initials: data.profile.initials,
                  season: data.profile.season,
                  rinks: summary.rinks,
                  prov: summary.provinces,
                  games: summary.games,
                  win: summary.winPercent)
    }

    var appData: AppData { data }
    var setupComplete: Bool { data.setupComplete }
    var profile: PlayerProfile { data.profile }
    var curlers: [Curler] { data.curlers }
    var stops: [Stop] { data.stops }
    var visits: [StopVisit] { data.visits }
    var spiels: [Spiel] { data.spiels }
    var attendance: [SpielAttendance] { data.attendance }
    var results: [GameResult] { data.results }
    var feed: [FeedItem] { data.feed }
    var bonspiels: [BonspielRecord] { data.bonspiels }

    var seasonSummary: SeasonSummary {
        let resultWins = data.results.filter { $0.res == "WIN" || $0.res == "W" }.count
        let games = max(0, data.profile.importedGameCount) + data.results.count
        let wins = max(0, data.profile.importedWinCount) + resultWins
        let winPercent = games == 0 ? 0 : Int((Double(wins) / Double(games) * 100).rounded())
        let visited = data.stops.filter { stopHasActivity($0.id) }
        let provinces = Set(visited.map(\.prov).filter { !$0.isEmpty && $0 != "TBD" }).count
        let met = Set(data.visits.flatMap(\.curlerIDs) + data.stops.flatMap(\.met) + data.results.flatMap(\.participantCurlerIDs)).count
        return SeasonSummary(rinks: visited.count,
                             provinces: provinces,
                             games: games,
                             winPercent: winPercent,
                             wins: wins,
                             met: met,
                             kilometers: 0,
                             distanceLabel: "—")
    }

    var needsOnboarding: Bool { !data.setupComplete }

    var lockerFeed: [FeedItem] {
        data.results.map { .result($0.asFeedPost(profile: data.profile)) } + data.feed
    }

    var lockerFollowingFeed: [FeedItem] {
        lockerFeed.filter(feedVisibleToFollowing)
    }

    var discoverSuggestions: [Curler] {
        var referenced = Set<String>()
        data.stops.flatMap(\.met).forEach { referenced.insert($0) }
        data.spiels.flatMap(\.going).forEach { referenced.insert($0) }
        data.visits.flatMap(\.curlerIDs).forEach { referenced.insert($0) }
        data.results.flatMap(\.participantCurlerIDs).forEach { referenced.insert($0) }
        for bonspiel in data.bonspiels {
            for team in bonspiel.teams {
                for member in team.members {
                    if let curlerID = member.curlerID {
                        referenced.insert(curlerID)
                    }
                }
            }
        }
        return data.curlers.filter { !$0.following && referenced.contains($0.id) }
    }

    var allActivityStops: [Stop] {
        data.stops.filter { stopHasActivity($0.id) }
    }

    var recentStops: [Stop] {
        allActivityStops.sorted { lhs, rhs in
            let lhsActive = isCurrentStop(lhs.id)
            let rhsActive = isCurrentStop(rhs.id)
            if lhsActive != rhsActive { return lhsActive }
            return lhs.name < rhs.name
        }
        .prefix(4)
        .map { $0 }
    }

    func curler(_ id: String) -> Curler? { data.curlers.first(where: { $0.id == id }) }
    func stop(_ id: String) -> Stop? { data.stops.first(where: { $0.id == id }) }
    func bonspiel(_ id: String) -> BonspielRecord? {
        data.bonspiels.first(where: { $0.id == id })
    }
    func bonspiel(for spielID: String) -> BonspielRecord? {
        data.bonspiels.first(where: { $0.linkedSpielID == spielID })
    }
    func bonspielGame(bonspielID: String, gameID: String) -> BonspielGame? {
        bonspiel(bonspielID)?.games.first(where: { $0.id == gameID })
    }
    func gameResult(_ id: UUID) -> GameResult? {
        data.results.first(where: { $0.id == id })
    }

    func lineupIsLocked(bonspielID: String, gameID: String) -> Bool {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else { return true }
        return lineupIsLocked(game, record: record)
    }

    func lineupValidationMessage(bonspielID: String, gameID: String, teamID: String, slots: [BonspielLineupSlot]) -> String? {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else {
            return "Bonspiel game not found."
        }
        return lineupValidationMessage(record: record, game: game, teamID: teamID, slots: slots)
    }

    func scorecardValidationMessage(bonspielID: String, gameID: String) -> String? {
        guard let game = bonspielGame(bonspielID: bonspielID, gameID: gameID) else {
            return "Bonspiel game not found."
        }
        return scorecardValidationMessage(game)
    }

    func curlerProfile(_ id: String) -> CurlerProfileSummary? {
        guard let curler = curler(id) else { return nil }
        let relatedResults = data.results.filter { $0.participantCurlerIDs.contains(id) }
        let wins = relatedResults.filter { $0.res == "WIN" || $0.res == "W" }.count
        let losses = relatedResults.filter { $0.res == "LOSS" || $0.res == "L" }.count
        let ties = relatedResults.filter { $0.res == "TIE" }.count
        let total = wins + losses + ties
        let imported = curler.importedHistory

        let record = total > 0 ? [wins, losses, ties].map(String.init).joined(separator: "-") : (imported?.record ?? "—")
        let win = total > 0 ? "\(Int((Double(wins) / Double(total) * 100).rounded()))%" : (imported?.win ?? "—")
        let shared = derivedSharedRinks(for: id)
        let displayShared = shared.isEmpty ? (imported?.sharedRinks ?? []) : shared
        let form = derivedRecentForm(for: id)
        let derivedMutual = derivedMutualCount(for: id)

        return CurlerProfileSummary(curler: curler,
                                    record: record,
                                    win: win,
                                    rinks: shared.isEmpty ? (imported?.rinks ?? displayShared.count) : shared.count,
                                    mutual: derivedMutual == 0 ? (imported?.mutual ?? 0) : derivedMutual,
                                    sharedRinks: displayShared,
                                    recentForm: form.isEmpty ? (imported?.form ?? []) : form)
    }

    func curlerConnectionLabel(_ id: String) -> String {
        if let stop = data.stops.first(where: { peopleMetIDs(for: $0.id).contains(id) }) {
            return "Met at \(stop.club.isEmpty ? stop.name : stop.club)"
        }
        guard let curler = curler(id) else { return "Local circle member" }
        if curler.metAt.localizedCaseInsensitiveContains("Added to") {
            return "Added to your circle"
        }
        return "Imported note: \(curler.metAt)"
    }

    func isFollowing(_ id: String) -> Bool { curler(id)?.following ?? false }

    func stopResults(_ stopID: String) -> [GameResult] {
        data.results.filter { $0.stopID == stopID }
    }

    func peopleMetIDs(for stopID: String) -> [String] {
        let fromVisits = data.visits.filter { $0.stopID == stopID }.flatMap(\.curlerIDs)
        let fromStop = stop(stopID)?.met ?? []
        return Array(Set(fromVisits + fromStop)).sorted()
    }

    private func derivedSharedRinks(for curlerID: String) -> [String] {
        var labels = Set<String>()
        for stop in data.stops {
            let metHere = peopleMetIDs(for: stop.id).contains(curlerID)
            let resultHere = data.results.contains { $0.stopID == stop.id && $0.participantCurlerIDs.contains(curlerID) }
            if metHere || resultHere {
                labels.insert(stop.club.isEmpty ? stop.name : stop.club)
            }
        }
        return labels.sorted()
    }

    private func derivedRecentForm(for curlerID: String) -> [GameLine] {
        data.results
            .filter { $0.participantCurlerIDs.contains(curlerID) }
            .prefix(5)
            .map { result in
                let context = result.stopID.flatMap { stop($0)?.name } ?? (result.opponent.isEmpty ? "Logged result" : "vs \(result.opponent)")
                let badge: String
                switch result.res {
                case "WIN": badge = "W"
                case "LOSS": badge = "L"
                case "TIE": badge = "T"
                default: badge = result.res
                }
                return GameLine(label: context, score: result.scoreLabel, res: badge)
            }
    }

    private func derivedMutualCount(for curlerID: String) -> Int {
        var mutuals = Set<String>()
        for visit in data.visits where visit.curlerIDs.contains(curlerID) {
            visit.curlerIDs.filter { $0 != curlerID && $0 != "me" }.forEach { mutuals.insert($0) }
        }
        for result in data.results where result.participantCurlerIDs.contains(curlerID) {
            result.participantCurlerIDs.filter { $0 != curlerID && $0 != "me" }.forEach { mutuals.insert($0) }
        }
        for bonspiel in data.bonspiels {
            for team in bonspiel.teams where team.members.contains(where: { $0.curlerID == curlerID }) {
                team.members.compactMap(\.curlerID)
                    .filter { $0 != curlerID && $0 != "me" }
                    .forEach { mutuals.insert($0) }
            }
        }
        return mutuals.count
    }

    func isCurrentStop(_ stopID: String) -> Bool {
        data.visits.contains { $0.stopID == stopID && $0.isActive }
    }

    func attendeeIDs(for spielID: String) -> [String] {
        data.attendance
            .filter { $0.spielID == spielID && $0.status == .going }
            .map(\.curlerID)
            .reduce(into: [String]()) { result, id in
                if !result.contains(id) { result.append(id) }
            }
    }

    func attendanceCount(for spielID: String) -> Int {
        attendeeIDs(for: spielID).count
    }

    func isAttendingSpiel(_ spielID: String, curlerID: String = "me") -> Bool {
        data.attendance.contains { $0.spielID == spielID && $0.curlerID == curlerID && $0.status == .going }
    }

    func spielID(named name: String) -> String? {
        data.spiels.first { $0.name == name }?.id
    }

    func isAttendingSpiel(named name: String, curlerID: String = "me") -> Bool {
        guard let id = spielID(named: name) else { return false }
        return isAttendingSpiel(id, curlerID: curlerID)
    }

    @discardableResult
    func toggleFollow(_ id: String) -> MutationReceipt {
        mutate(action: "toggleFollow",
               domains: [.curlers, .feed],
               message: "Follow state updated.",
               focusRoute: .curler(id)) { draft in
            guard let i = draft.curlers.firstIndex(where: { $0.id == id }) else { return }
            draft.curlers[i].following.toggle()
        }
    }

    @discardableResult
    func followAll(_ ids: [String]) -> MutationReceipt {
        mutate(action: "followAll",
               domains: [.curlers, .feed],
               message: "Curlers added to your circle.") { draft in
            for id in ids {
                guard let i = draft.curlers.firstIndex(where: { $0.id == id }) else { continue }
                draft.curlers[i].following = true
            }
        }
    }

    func initials(for ids: [String], limit: Int = 2) -> [String] {
        ids.compactMap { id in
            id == "me" ? data.profile.initials : curler(id)?.initials
        }
        .prefix(limit)
        .map { $0 }
    }

    func plusLabel(for ids: [String], visible: Int = 2) -> String? {
        let hidden = ids.filter { $0 == "me" || curler($0) != nil }.count - visible
        return hidden > 0 ? "+\(hidden)" : nil
    }

    @discardableResult
    func deleteFeedItem(_ id: UUID) -> MutationReceipt {
        mutate(action: "deleteFeedItem",
               domains: [.feed, .results],
               message: "Post deleted.") { draft in
            draft.results.removeAll { $0.id == id }
            draft.feed.removeAll { $0.id == id }
        }
    }

    @discardableResult
    func deleteCurler(_ id: String) -> MutationReceipt {
        mutate(action: "deleteCurler",
               domains: [.curlers, .stops, .visits, .spiels, .attendance, .results, .bonspiels],
               message: "Curler removed.") { draft in
            draft.curlers.removeAll { $0.id == id }
            for i in draft.stops.indices {
                draft.stops[i].met.removeAll { $0 == id }
            }
            for i in draft.spiels.indices {
                draft.spiels[i].going.removeAll { $0 == id }
            }
            for i in draft.visits.indices {
                draft.visits[i].curlerIDs.removeAll { $0 == id }
            }
            draft.attendance.removeAll { $0.curlerID == id }
            for i in draft.results.indices {
                draft.results[i].participantCurlerIDs.removeAll { $0 == id }
            }
            for bonspielIndex in draft.bonspiels.indices {
                for teamIndex in draft.bonspiels[bonspielIndex].teams.indices {
                    for memberIndex in draft.bonspiels[bonspielIndex].teams[teamIndex].members.indices where draft.bonspiels[bonspielIndex].teams[teamIndex].members[memberIndex].curlerID == id {
                        draft.bonspiels[bonspielIndex].teams[teamIndex].members[memberIndex].curlerID = nil
                    }
                }
            }
        }
    }

    @discardableResult
    func markStopVisited(_ id: String) -> MutationReceipt {
        startVisit(stopID: id, curlerIDs: [], note: "")
    }

    @discardableResult
    func startVisit(stopID: String, curlerIDs: [String], note: String, arrivedAt: String = "now") -> MutationReceipt {
        guard data.stops.contains(where: { $0.id == stopID }) else {
            return blockedReceipt(action: "startVisit", message: "Stop not found.")
        }
        let validCurlerIDs = curlerIDs
            .filter { curler($0) != nil }
            .reduce(into: [String]()) { result, id in
                if !result.contains(id) { result.append(id) }
            }
        return mutate(action: "startVisit",
                      domains: [.visits, .stops],
                      message: "Visit started.",
                      focusRoute: .stop(stopID)) { draft in
            for i in draft.visits.indices where draft.visits[i].isActive {
                draft.visits[i].departedAt = arrivedAt
            }
            draft.visits.insert(StopVisit(stopID: stopID,
                                          arrivedAt: arrivedAt,
                                          departedAt: nil,
                                          curlerIDs: validCurlerIDs,
                                          note: note),
                                at: 0)
        }
    }

    @discardableResult
    func endVisit(stopID: String, departedAt: String = "now") -> MutationReceipt {
        mutate(action: "endVisit",
               domains: [.visits],
               message: "Visit ended.",
               focusRoute: .stop(stopID)) { draft in
            for i in draft.visits.indices where draft.visits[i].stopID == stopID && draft.visits[i].isActive {
                draft.visits[i].departedAt = departedAt
            }
        }
    }

    @discardableResult
    func startDemoSeason() -> MutationReceipt {
        let previous = data
        apply(Seed.appData(setupComplete: true), shouldPersist: true)
        return receipt(action: "startDemoSeason",
                       domains: [.setup, .profile, .curlers, .stops, .visits, .spiels, .attendance, .results, .feed, .bonspiels],
                       message: "Demo season loaded.",
                       previous: previous)
    }

    @discardableResult
    func startBlankSeason(name: String, homeClub: String, province: String) -> MutationReceipt {
        let blankProfile = PlayerProfile.blank(name: name, homeClub: homeClub, province: province)
        let previous = data
        apply(AppData(schemaVersion: 4,
                      setupComplete: true,
                      profile: blankProfile,
                      curlers: [],
                      stops: [],
                      visits: [],
                      spiels: [],
                      attendance: [],
                      results: [],
                      feed: [],
                      bonspiels: []),
              shouldPersist: true)
        return receipt(action: "startBlankSeason",
                       domains: [.setup, .profile, .curlers, .stops, .visits, .spiels, .attendance, .results, .feed, .bonspiels],
                       message: "Blank season started.",
                       previous: previous)
    }

    @discardableResult
    func clearSeason() -> MutationReceipt {
        let previous = data
        apply(AppData(schemaVersion: 4,
                      setupComplete: true,
                      profile: PlayerProfile.blank(name: profile.name,
                                                   homeClub: profile.homeClub,
                                                   province: profile.homeProvince),
                      curlers: [],
                      stops: [],
                      visits: [],
                      spiels: [],
                      attendance: [],
                      results: [],
                      feed: [],
                      bonspiels: []),
              shouldPersist: true)
        return receipt(action: "clearSeason",
                       domains: [.setup, .profile, .curlers, .stops, .visits, .spiels, .attendance, .results, .feed, .bonspiels],
                       message: "Season cleared.",
                       previous: previous)
    }

    @discardableResult
    func resetToSetup() -> MutationReceipt {
        mutate(action: "resetToSetup",
               domains: [.setup],
               message: "Setup will show on next launch.") { draft in
            draft.setupComplete = false
        }
    }

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(appData),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    @discardableResult
    func importJSON(_ text: String) throws -> MutationReceipt {
        guard let data = text.data(using: .utf8),
              let imported = try? JSONDecoder().decode(AppData.self, from: data) else {
            throw StoreDataError.invalidJSON
        }
        return try importData(imported)
    }

    @discardableResult
    func importData(_ imported: AppData) throws -> MutationReceipt {
        guard imported.schemaVersion <= 4 else { throw StoreDataError.unsupportedVersion(imported.schemaVersion) }
        guard !imported.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreDataError.emptyProfile
        }
        let previous = data
        var normalized = Self.normalized(imported)
        normalized.setupComplete = true
        apply(normalized, shouldPersist: true)
        return receipt(action: "importData",
                       domains: [.setup, .profile, .curlers, .stops, .visits, .spiels, .attendance, .results, .feed, .bonspiels],
                       message: "Season imported.",
                       previous: previous)
    }

    // MARK: - Create actions

    private static func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func displayDateRange(startISO: String, endISO: String) -> String {
        guard let start = parseISODate(startISO),
              let end = parseISODate(endISO) else {
            return startISO == endISO ? startISO : "\(startISO)-\(endISO)"
        }
        let calendar = Calendar.current
        let month = DateFormatter()
        month.locale = Locale(identifier: "en_US_POSIX")
        month.dateFormat = "MMM"
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "d"

        if calendar.isDate(start, inSameDayAs: end) {
            return "\(month.string(from: start)) \(day.string(from: start))".uppercased()
        }
        if calendar.component(.month, from: start) == calendar.component(.month, from: end),
           calendar.component(.year, from: start) == calendar.component(.year, from: end) {
            return "\(month.string(from: start)) \(day.string(from: start))-\(day.string(from: end))".uppercased()
        }
        return "\(month.string(from: start)) \(day.string(from: start))-\(month.string(from: end)) \(day.string(from: end))".uppercased()
    }

    private static func parseISODate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    @discardableResult
    func addSpiel(name: String, whereText: String, whenText: String, status: String, discipline: CurlingDiscipline) -> MutationReceipt {
        addSpiel(name: name,
                 whereText: whereText,
                 whenText: whenText,
                 status: status,
                 discipline: discipline,
                 startDate: nil,
                 endDate: nil)
    }

    @discardableResult
    func addSpiel(name: String, whereText: String, startDate: Date, endDate: Date, status: String, discipline: CurlingDiscipline) -> MutationReceipt {
        let orderedStart = min(startDate, endDate)
        let orderedEnd = max(startDate, endDate)
        let startISO = Self.isoDateString(orderedStart)
        let endISO = Self.isoDateString(orderedEnd)
        return addSpiel(name: name,
                        whereText: whereText,
                        whenText: Self.displayDateRange(startISO: startISO, endISO: endISO),
                        status: status,
                        discipline: discipline,
                        startDate: startISO,
                        endDate: endISO)
    }

    @discardableResult
    private func addSpiel(name: String,
                          whereText: String,
                          whenText: String,
                          status: String,
                          discipline: CurlingDiscipline,
                          startDate: String?,
                          endDate: String?) -> MutationReceipt {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = whereText.trimmingCharacters(in: .whitespacesAndNewlines)
        let routeLocation = SpielRouteLocation.resolve(cleanLocation)
        let spielID = "sp-\(UUID().uuidString.prefix(6))"
        let spiel = Spiel(id: spielID,
                          name: cleanName,
                          whereText: cleanLocation.isEmpty ? "TBD" : cleanLocation,
                          whenText: whenText.isEmpty ? "DATE TBD" : whenText,
                          status: status,
                          going: [],
                          startDate: startDate,
                          endDate: endDate,
                          stopID: routeLocation == nil ? nil : "stop-\(spielID)")
        let routeStop = routeLocation?.stop(spielID: spiel.id, name: spiel.name, dateText: spiel.whenText)
        var domains: Set<SeasonDomain> = [.spiels, .bonspiels]
        if routeStop != nil { domains.insert(.stops) }
        return mutate(action: "addSpiel",
                      domains: domains,
                      message: "Spiel added.") { draft in
            draft.spiels.insert(spiel, at: 0)
            if let routeStop {
                draft.stops.insert(routeStop, at: 0)
            }
            draft.bonspiels.insert(BonspielRecord.defaultLinked(spielID: spiel.id,
                                                                name: spiel.name,
                                                                whereText: spiel.whereText,
                                                                whenText: spiel.whenText,
                                                                discipline: discipline,
                                                                homeClub: draft.profile.homeClub,
                                                                startDate: startDate,
                                                                endDate: endDate,
                                                                venue: routeLocation?.venue,
                                                                timezone: routeLocation?.timezone),
                                   at: 0)
        }
    }

    @discardableResult
    func setSpielStatus(_ id: String, _ status: String) -> MutationReceipt {
        mutate(action: "setSpielStatus",
               domains: [.spiels],
               message: "Spiel status updated.") { draft in
            guard let i = draft.spiels.firstIndex(where: { $0.id == id }) else { return }
            draft.spiels[i].status = status
        }
    }

    @discardableResult
    func addResult(body: String, scoreFor: Int, scoreAgainst: Int, vs: String, stopID: String? = nil, spielID: String? = nil, participantCurlerIDs: [String] = []) -> MutationReceipt {
        let res = scoreFor == scoreAgainst ? "TIE" : (scoreFor > scoreAgainst ? "WIN" : "LOSS")
        let opp = vs.trimmingCharacters(in: .whitespaces)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let validStopID = stopID.flatMap { stop($0) == nil ? nil : $0 }
        let validSpielID = spielID.flatMap { id in data.spiels.contains(where: { $0.id == id }) ? id : nil }
        let validParticipants = participantCurlerIDs
            .filter { curler($0) != nil }
            .reduce(into: [String]()) { result, id in
                if !result.contains(id) { result.append(id) }
            }
        let result = GameResult(createdAt: "now",
                                note: cleanBody.isEmpty ? "\(res.capitalized) \(scoreFor)-\(scoreAgainst)." : cleanBody,
                                opponent: opp,
                                scoreFor: scoreFor,
                                scoreAgainst: scoreAgainst,
                                stopID: validStopID,
                                spielID: validSpielID,
                                participantCurlerIDs: validParticipants,
                                ends: [],
                                conceded: false,
                                forfeited: false,
                                locallyConfirmed: true)
        return mutate(action: "addResult",
                      domains: [.results, .feed],
                      message: "Result recorded.") { draft in
            draft.results.insert(result, at: 0)
        }
    }

    @discardableResult
    func updateResult(id: UUID, body: String, scoreFor: Int, scoreAgainst: Int, vs: String) -> MutationReceipt {
        guard data.results.contains(where: { $0.id == id }) else {
            return blockedReceipt(action: "updateResult", message: "Result not found.")
        }
        return mutate(action: "updateResult",
                      domains: [.results, .feed],
                      message: "Result updated.") { draft in
            guard let i = draft.results.firstIndex(where: { $0.id == id }) else { return }
            draft.results[i].note = body.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.results[i].opponent = vs.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.results[i].scoreFor = scoreFor
            draft.results[i].scoreAgainst = scoreAgainst
        }
    }

    @discardableResult
    func deleteResult(_ id: UUID) -> MutationReceipt {
        guard data.results.contains(where: { $0.id == id }) else {
            return blockedReceipt(action: "deleteResult", message: "Result not found.")
        }
        return mutate(action: "deleteResult",
                      domains: [.results, .feed],
                      message: "Result deleted.") { draft in
            draft.results.removeAll { $0.id == id }
        }
    }

    @discardableResult
    func addCurler(name: String, role: String, club: String, prov: String) -> MutationReceipt {
        let initials = name.split(separator: " ").prefix(2)
            .compactMap { $0.first }.map(String.init).joined().uppercased()
        let curler = Curler(id: "c-\(UUID().uuidString.prefix(6))",
                            initials: initials.isEmpty ? "?" : initials,
                            name: name,
                            role: role.isEmpty ? "Curler" : role,
                            club: club.isEmpty ? "—" : club,
                            prov: prov.isEmpty ? "—" : prov,
                            metAt: "Added to your roster", following: true,
                            record: "0–0", win: "—", rinks: 0, mutual: 0,
                            sharedRinks: [], form: [])
        return mutate(action: "addCurler",
                      domains: [.curlers],
                      message: "Curler added.",
                      focusRoute: .curler(curler.id)) { draft in
            draft.curlers.insert(curler, at: 0)
        }
    }

    @discardableResult
    func setAttendance(spielID: String, curlerID: String = "me", isGoing: Bool, updatedAt: String = "now") -> MutationReceipt {
        mutate(action: "setAttendance",
               domains: [.attendance, .spiels, .feed],
               message: isGoing ? "Attendance saved." : "Attendance removed.") { draft in
            guard draft.spiels.contains(where: { $0.id == spielID }) else { return }
            draft.attendance.removeAll { $0.spielID == spielID && $0.curlerID == curlerID }
            draft.attendance.append(SpielAttendance(spielID: spielID,
                                                    curlerID: curlerID,
                                                    status: isGoing ? .going : .notGoing,
                                                    updatedAt: updatedAt))
        }
    }

    @discardableResult
    func toggleAttendance(forSpielNamed name: String, curlerID: String = "me") -> MutationReceipt {
        guard let spielID = spielID(named: name) else {
            return MutationReceipt(action: "toggleAttendance",
                                   changedDomains: [],
                                   userMessage: "Spiel not found.",
                                   focusRoute: nil,
                                   undoToken: nil)
        }
        return setAttendance(spielID: spielID, curlerID: curlerID, isGoing: !isAttendingSpiel(spielID, curlerID: curlerID))
    }

    @discardableResult
    func addBonspielTeamMember(bonspielID: String,
                               teamID: String,
                               displayName: String,
                               role: String,
                               rosterStatus: String,
                               declaredPosition: String,
                               curlerID: String? = nil) -> MutationReceipt {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return blockedReceipt(action: "addBonspielTeamMember", message: "Team member needs a name.")
        }
        if let curlerID, curlerID != "me", curler(curlerID) == nil {
            return blockedReceipt(action: "addBonspielTeamMember", message: "Linked curler not found.")
        }
        guard bonspiel(bonspielID)?.teams.contains(where: { $0.id == teamID }) == true else {
            return blockedReceipt(action: "addBonspielTeamMember", message: "Bonspiel team not found.")
        }

        let member = BonspielTeamMember(id: "member-\(UUID().uuidString.prefix(8))",
                                        curlerID: curlerID,
                                        displayName: cleanName,
                                        role: role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "player" : role,
                                        rosterStatus: rosterStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "active" : rosterStatus,
                                        declaredPosition: declaredPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player" : declaredPosition)
        return mutate(action: "addBonspielTeamMember",
                      domains: [.bonspiels],
                      message: "Team member added.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let teamIndex = draft.bonspiels[bonspielIndex].teams.firstIndex(where: { $0.id == teamID }) else { return }
            draft.bonspiels[bonspielIndex].teams[teamIndex].members.append(member)
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func removeBonspielTeamMember(bonspielID: String, teamID: String, memberID: String) -> MutationReceipt {
        guard let record = bonspiel(bonspielID),
              record.teams.contains(where: { $0.id == teamID }) else {
            return blockedReceipt(action: "removeBonspielTeamMember", message: "Bonspiel team not found.")
        }
        let lockedUse = record.games.contains { game in
            lineupIsLocked(game, record: record) && game.gameLineups.contains { lineup in
                lineup.teamID == teamID && lineup.deliveryRotation.contains(where: { $0.memberID == memberID })
            }
        }
        guard !lockedUse else {
            return blockedReceipt(action: "removeBonspielTeamMember", message: "Member is locked into a submitted lineup. Record a lineup change instead.")
        }

        return mutate(action: "removeBonspielTeamMember",
                      domains: [.bonspiels],
                      message: "Team member removed.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let teamIndex = draft.bonspiels[bonspielIndex].teams.firstIndex(where: { $0.id == teamID }) else { return }
            draft.bonspiels[bonspielIndex].teams[teamIndex].members.removeAll { $0.id == memberID }
            for gameIndex in draft.bonspiels[bonspielIndex].games.indices {
                for lineupIndex in draft.bonspiels[bonspielIndex].games[gameIndex].gameLineups.indices {
                    guard draft.bonspiels[bonspielIndex].games[gameIndex].gameLineups[lineupIndex].teamID == teamID else { continue }
                    draft.bonspiels[bonspielIndex].games[gameIndex].gameLineups[lineupIndex].deliveryRotation.removeAll { $0.memberID == memberID }
                }
            }
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func submitBonspielLineup(bonspielID: String,
                              gameID: String,
                              teamID: String,
                              slots: [BonspielLineupSlot],
                              submittedAt: String = "now",
                              source: String = "local_game_lineup") -> MutationReceipt {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else {
            return blockedReceipt(action: "submitBonspielLineup", message: "Bonspiel game not found.")
        }
        guard !lineupIsLocked(game, record: record) else {
            return blockedReceipt(action: "submitBonspielLineup", message: "Lineup is locked for this game.")
        }
        if let message = lineupValidationMessage(record: record, game: game, teamID: teamID, slots: slots) {
            return blockedReceipt(action: "submitBonspielLineup", message: message)
        }

        return mutate(action: "submitBonspielLineup",
                      domains: [.bonspiels],
                      message: "Lineup submitted.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            var game = draft.bonspiels[bonspielIndex].games[gameIndex]
            let lineup = BonspielGameLineup(id: game.gameLineups.first(where: { $0.teamID == teamID })?.id ?? "lineup-\(UUID().uuidString.prefix(8))",
                                            teamID: teamID,
                                            submittedAt: submittedAt,
                                            source: source,
                                            deliveryRotation: slots,
                                            alternateMemberID: nil,
                                            coachName: nil)
            if let existingIndex = game.gameLineups.firstIndex(where: { $0.teamID == teamID }) {
                game.gameLineups[existingIndex] = lineup
            } else {
                game.gameLineups.append(lineup)
            }
            if game.status == .scheduled {
                game.status = .readyForLineup
            }
            game.version += 1
            draft.bonspiels[bonspielIndex].games[gameIndex] = game
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func lockBonspielLineup(bonspielID: String, gameID: String) -> MutationReceipt {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else {
            return blockedReceipt(action: "lockBonspielLineup", message: "Bonspiel game not found.")
        }
        for teamID in [game.teamAID, game.teamBID] {
            guard let lineup = game.gameLineups.first(where: { $0.teamID == teamID }) else {
                return blockedReceipt(action: "lockBonspielLineup", message: "Both teams need a lineup before lock.")
            }
            if let message = lineupValidationMessage(record: record, game: game, teamID: teamID, slots: lineup.deliveryRotation) {
                return blockedReceipt(action: "lockBonspielLineup", message: message)
            }
        }

        return mutate(action: "lockBonspielLineup",
                      domains: [.bonspiels],
                      message: "Lineup locked.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            draft.bonspiels[bonspielIndex].games[gameIndex].status = .lineupLocked
            draft.bonspiels[bonspielIndex].games[gameIndex].version += 1
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func addBonspielLineupChange(bonspielID: String,
                                 gameID: String,
                                 teamID: String,
                                 outgoingMemberID: String?,
                                 incomingName: String,
                                 effectiveEnd: Int,
                                 reason: String,
                                 approvedBy: String = "local scorer") -> MutationReceipt {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else {
            return blockedReceipt(action: "addBonspielLineupChange", message: "Bonspiel game not found.")
        }
        guard lineupIsLocked(game, record: record) else {
            return blockedReceipt(action: "addBonspielLineupChange", message: "Submit or edit the lineup before lock.")
        }
        guard effectiveEnd > 0 else {
            return blockedReceipt(action: "addBonspielLineupChange", message: "Effective end must be positive.")
        }
        let cleanName = incomingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return blockedReceipt(action: "addBonspielLineupChange", message: "Incoming player needs a name.")
        }

        return mutate(action: "addBonspielLineupChange",
                      domains: [.bonspiels],
                      message: "Lineup change recorded.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            draft.bonspiels[bonspielIndex].games[gameIndex].lineupChanges.append(
                BonspielLineupChange(id: "change-\(UUID().uuidString.prefix(8))",
                                     teamID: teamID,
                                     outgoingMemberID: outgoingMemberID,
                                     incomingName: cleanName,
                                     effectiveEnd: effectiveEnd,
                                     reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                     approvedBy: approvedBy)
            )
            draft.bonspiels[bonspielIndex].games[gameIndex].version += 1
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func recordBonspielEndScore(bonspielID: String,
                                gameID: String,
                                endNumber: Int,
                                teamA: Int,
                                teamB: Int,
                                isBlank: Bool = false,
                                isExtraEnd: Bool = false,
                                hammerTeamIDStart: String? = nil,
                                measureRequired: Bool = false,
                                powerPlayUsed: Bool = false) -> MutationReceipt {
        guard let game = bonspielGame(bonspielID: bonspielID, gameID: gameID) else {
            return blockedReceipt(action: "recordBonspielEndScore", message: "Bonspiel game not found.")
        }
        guard game.status != .finalized else {
            return blockedReceipt(action: "recordBonspielEndScore", message: "Finalized scorecards need a correction flow.")
        }
        if let message = endScoreValidationMessage(game: game,
                                                   endNumber: endNumber,
                                                   teamA: teamA,
                                                   teamB: teamB,
                                                   isBlank: isBlank,
                                                   isExtraEnd: isExtraEnd) {
            return blockedReceipt(action: "recordBonspielEndScore", message: message)
        }

        let score = BonspielEndScore(id: "\(gameID)-e\(endNumber)",
                                     endNumber: endNumber,
                                     teamA: teamA,
                                     teamB: teamB,
                                     hammerTeamIDStart: hammerTeamIDStart,
                                     isBlank: isBlank,
                                     isExtraEnd: isExtraEnd,
                                     measureRequired: measureRequired,
                                     powerPlayUsed: powerPlayUsed)
        return mutate(action: "recordBonspielEndScore",
                      domains: [.bonspiels],
                      message: "End score saved.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            if let endIndex = draft.bonspiels[bonspielIndex].games[gameIndex].ends.firstIndex(where: { $0.endNumber == endNumber }) {
                draft.bonspiels[bonspielIndex].games[gameIndex].ends[endIndex] = score
            } else {
                draft.bonspiels[bonspielIndex].games[gameIndex].ends.append(score)
            }
            draft.bonspiels[bonspielIndex].games[gameIndex].ends.sort { $0.endNumber < $1.endNumber }
            if [.scheduled, .readyForLineup, .lineupLocked].contains(draft.bonspiels[bonspielIndex].games[gameIndex].status) {
                draft.bonspiels[bonspielIndex].games[gameIndex].status = .inProgress
            }
            draft.bonspiels[bonspielIndex].games[gameIndex].version += 1
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func setBonspielResultFlags(bonspielID: String,
                                gameID: String,
                                conceded: Bool,
                                forfeited: Bool) -> MutationReceipt {
        guard bonspielGame(bonspielID: bonspielID, gameID: gameID) != nil else {
            return blockedReceipt(action: "setBonspielResultFlags", message: "Bonspiel game not found.")
        }
        return mutate(action: "setBonspielResultFlags",
                      domains: [.bonspiels],
                      message: "Result flags saved.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            draft.bonspiels[bonspielIndex].games[gameIndex].resultFlags.conceded = conceded
            draft.bonspiels[bonspielIndex].games[gameIndex].resultFlags.forfeited = forfeited
            if forfeited {
                draft.bonspiels[bonspielIndex].games[gameIndex].status = .forfeit
            }
            draft.bonspiels[bonspielIndex].games[gameIndex].version += 1
            draft.bonspiels[bonspielIndex].version += 1
        }
    }

    @discardableResult
    func confirmBonspielGameResult(bonspielID: String,
                                   gameID: String,
                                   confirmedBy: String = "me",
                                   confirmedAt: String = "now") -> MutationReceipt {
        guard let record = bonspiel(bonspielID),
              let game = record.games.first(where: { $0.id == gameID }) else {
            return blockedReceipt(action: "confirmBonspielGameResult", message: "Bonspiel game not found.")
        }
        if let message = scorecardValidationMessage(game) {
            return blockedReceipt(action: "confirmBonspielGameResult", message: message)
        }

        return mutate(action: "confirmBonspielGameResult",
                      domains: [.bonspiels, .results, .feed],
                      message: "Local scorecard confirmed.") { draft in
            guard let bonspielIndex = draft.bonspiels.firstIndex(where: { $0.id == bonspielID }),
                  let gameIndex = draft.bonspiels[bonspielIndex].games.firstIndex(where: { $0.id == gameID }) else { return }
            var game = draft.bonspiels[bonspielIndex].games[gameIndex]
            game.resultFlags.isFinal = true
            game.scoreAgreement = BonspielScoreAgreement(confirmed: true,
                                                         confirmedAt: confirmedAt,
                                                         confirmedBy: confirmedBy)
            game.status = game.resultFlags.forfeited ? .forfeit : .finalized
            game.version += 1
            draft.bonspiels[bonspielIndex].games[gameIndex] = game
            draft.bonspiels[bonspielIndex].version += 1

            let participantIDs = participantCurlerIDs(record: draft.bonspiels[bonspielIndex], game: game)
            var result = GameResult(authorID: nil,
                                    createdAt: game.scheduledStartAt,
                                    note: "Local scorecard: \(draft.bonspiels[bonspielIndex].teamName(game.teamAID)) vs \(draft.bonspiels[bonspielIndex].teamName(game.teamBID)).",
                                    opponent: draft.bonspiels[bonspielIndex].teamName(game.teamBID),
                                    scoreFor: game.teamATotal,
                                    scoreAgainst: game.teamBTotal,
                                    stopID: nil,
                                    spielID: draft.bonspiels[bonspielIndex].linkedSpielID,
                                    participantCurlerIDs: participantIDs,
                                    ends: game.ends,
                                    conceded: game.resultFlags.conceded,
                                    forfeited: game.resultFlags.forfeited,
                                    locallyConfirmed: true)
            result.bonspielID = bonspielID
            result.bonspielGameID = gameID

            if let existingIndex = draft.results.firstIndex(where: { $0.bonspielGameID == gameID }) {
                result.id = draft.results[existingIndex].id
                draft.results[existingIndex] = result
            } else {
                draft.results.insert(result, at: 0)
            }
        }
    }

    @discardableResult
    func undo(_ token: UndoToken) -> MutationReceipt? {
        guard let snapshot = undoSnapshots.removeValue(forKey: token.payloadID) else { return nil }
        let previous = data
        apply(snapshot, shouldPersist: true)
        return receipt(action: "undo",
                       domains: [.setup, .profile, .curlers, .stops, .visits, .spiels, .attendance, .results, .feed, .bonspiels],
                       message: "Undo complete.",
                       previous: previous)
    }

    private func apply(_ data: AppData, shouldPersist: Bool) {
        isHydrating = true
        self.data = Self.normalized(data)
        isHydrating = false
        if shouldPersist { persistAll() }
    }

    private func persistAll() {
        guard !isHydrating else { return }
        Persist.save(data, Persist.appDataKey)
    }

    private func feedVisibleToFollowing(_ item: FeedItem) -> Bool {
        switch item {
        case .result(let post):
            return post.author == "me" || curler(post.author)?.following == true
        case .spiel(let post):
            let followed = post.who.contains { curler($0)?.following == true }
            let attending = spielID(named: post.spielName).map { isAttendingSpiel($0) } ?? false
            return followed || attending
        case .review(let post):
            return curler(post.author)?.following == true
        }
    }

    private func stopHasActivity(_ stopID: String) -> Bool {
        data.visits.contains { $0.stopID == stopID }
            || data.results.contains { $0.stopID == stopID }
            || (stop(stopID).map { !$0.games.isEmpty || !$0.met.isEmpty || $0.record != "—" } ?? false)
    }

    private func mutate(action: String,
                        domains: Set<SeasonDomain>,
                        message: String,
                        focusRoute: Route? = nil,
                        _ body: (inout AppData) -> Void) -> MutationReceipt {
        let previous = data
        var draft = data
        body(&draft)
        data = Self.normalized(draft)
        return receipt(action: action,
                       domains: domains,
                       message: message,
                       focusRoute: focusRoute,
                       previous: previous)
    }

    private func receipt(action: String,
                         domains: Set<SeasonDomain>,
                         message: String,
                         focusRoute: Route? = nil,
                         previous: AppData) -> MutationReceipt {
        let tokenID = UUID().uuidString
        undoSnapshots[tokenID] = previous
        return MutationReceipt(action: action,
                               changedDomains: domains,
                               userMessage: message,
                               focusRoute: focusRoute,
                               undoToken: UndoToken(action: "restoreAppData", payloadID: tokenID))
    }

    private static func legacyAppData() -> AppData {
        var migrated = Seed.appData(setupComplete: true)
        if let saved: [Curler] = Persist.load(Persist.curlersKey) { migrated.curlers = saved }
        if let saved: [Spiel] = Persist.load(Persist.spielsKey) { migrated.spiels = saved }
        if let saved: [FeedItem] = Persist.load(Persist.feedKey) { migrated.feed = saved }
        return migrated
    }

    private func blockedReceipt(action: String, message: String, focusRoute: Route? = nil) -> MutationReceipt {
        MutationReceipt(action: action,
                        changedDomains: [],
                        userMessage: message,
                        focusRoute: focusRoute,
                        undoToken: nil)
    }

    private func lineupIsLocked(_ game: BonspielGame, record: BonspielRecord? = nil, now: Date = Date()) -> Bool {
        switch game.status {
        case .lineupLocked, .inProgress, .complete, .finalized, .forfeit, .cancelled:
            return true
        case .postponed:
            return false
        case .scheduled, .readyForLineup:
            break
        }
        guard let record else { return false }
        return scheduledLineupLockIsActive(record: record, game: game, now: now)
    }

    private func scheduledLineupLockIsActive(record: BonspielRecord, game: BonspielGame, now: Date) -> Bool {
        guard record.rosterPolicy.lockMinutesBeforeGame > 0,
              let start = scheduledStartDate(record: record, game: game) else {
            return false
        }
        let lockStart = start.addingTimeInterval(TimeInterval(-record.rosterPolicy.lockMinutesBeforeGame * 60))
        return now >= lockStart
    }

    private func scheduledStartDate(record: BonspielRecord, game: BonspielGame) -> Date? {
        let value = game.scheduledStartAt.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: record.timezone) ?? .current
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func lineupValidationMessage(record: BonspielRecord,
                                         game: BonspielGame,
                                         teamID: String,
                                         slots: [BonspielLineupSlot]) -> String? {
        guard teamID == game.teamAID || teamID == game.teamBID else {
            return "Lineup team is not assigned to this game."
        }
        guard let team = record.teams.first(where: { $0.id == teamID }) else {
            return "Bonspiel team not found."
        }
        guard slots.count == record.rosterPolicy.maxPlayersOnIce else {
            return "Lineup needs \(record.rosterPolicy.maxPlayersOnIce) players for \(record.discipline.label)."
        }
        let memberIDs = slots.map(\.memberID)
        guard Set(memberIDs).count == memberIDs.count else {
            return "Lineup cannot contain duplicate players."
        }
        guard slots.filter(\.isSkip).count == 1 else {
            return "Lineup needs exactly one skip."
        }
        guard slots.filter(\.isViceSkip).count == 1 else {
            return "Lineup needs exactly one vice skip."
        }

        let membersByID = Dictionary(uniqueKeysWithValues: team.members.map { ($0.id, $0) })
        for slot in slots {
            guard let member = membersByID[slot.memberID] else {
                return "Lineup contains a player outside the team roster."
            }
            let status = member.rosterStatus.lowercased()
            let role = member.role.lowercased()
            if (status == "spare" || role == "spare") && !record.rosterPolicy.allowSpares {
                return "Roster policy does not allow spares."
            }
            if (status == "alternate" || role == "alternate") && !record.rosterPolicy.allowAlternates {
                return "Roster policy does not allow alternates."
            }
        }

        return nil
    }

    private func endScoreValidationMessage(game: BonspielGame,
                                           endNumber: Int,
                                           teamA: Int,
                                           teamB: Int,
                                           isBlank: Bool,
                                           isExtraEnd: Bool) -> String? {
        guard endNumber > 0 else { return "End number must be positive." }
        guard teamA >= 0, teamB >= 0 else { return "End scores cannot be negative." }
        guard !(teamA > 0 && teamB > 0) else { return "Only one team can score in an end." }
        if isBlank {
            guard teamA == 0, teamB == 0 else { return "Blank ends must be 0-0." }
        } else if teamA == 0 && teamB == 0 {
            return "Mark 0-0 as a blank end."
        }
        if endNumber <= game.scheduledEnds && isExtraEnd {
            return "Regulation ends cannot be marked as extra ends."
        }
        if endNumber > game.scheduledEnds {
            guard isExtraEnd else { return "End \(endNumber) must be marked as an extra end." }
            let regulationEnds = game.ends.filter { $0.endNumber <= game.scheduledEnds && $0.endNumber != endNumber }
            guard regulationEnds.count >= game.scheduledEnds else {
                return "Extra ends require completed regulation ends."
            }
            let teamATotal = regulationEnds.reduce(0) { $0 + $1.teamA }
            let teamBTotal = regulationEnds.reduce(0) { $0 + $1.teamB }
            guard teamATotal == teamBTotal else {
                return "Extra ends are only valid after tied regulation."
            }
        }
        return nil
    }

    private func scorecardValidationMessage(_ game: BonspielGame) -> String? {
        if game.resultFlags.forfeited {
            return nil
        }
        guard !game.ends.isEmpty else {
            return "Enter at least one end before confirmation."
        }
        for end in game.ends {
            if let message = endScoreValidationMessage(game: game,
                                                       endNumber: end.endNumber,
                                                       teamA: end.teamA,
                                                       teamB: end.teamB,
                                                       isBlank: end.isBlank,
                                                       isExtraEnd: end.isExtraEnd) {
                return message
            }
        }
        guard game.completedEnds >= game.minEndsForLocalResult || game.resultFlags.conceded else {
            return "Game needs \(game.minEndsForLocalResult) completed ends or a concession."
        }
        guard game.teamATotal != game.teamBTotal || game.resultFlags.conceded else {
            return "Tied games need an extra end or a result flag before confirmation."
        }
        return nil
    }

    private func participantCurlerIDs(record: BonspielRecord, game: BonspielGame) -> [String] {
        var ids = Set<String>()
        for lineup in game.gameLineups {
            guard let team = record.teams.first(where: { $0.id == lineup.teamID }) else { continue }
            for slot in lineup.deliveryRotation {
                if let curlerID = team.members.first(where: { $0.id == slot.memberID })?.curlerID {
                    ids.insert(curlerID)
                }
            }
        }
        return ids.sorted()
    }

    private static func normalized(_ imported: AppData) -> AppData {
        var normalized = imported
        normalized.schemaVersion = 4

        if normalized.bonspiels.isEmpty && normalized.profile.demoMode && !normalized.spiels.isEmpty {
            normalized.bonspiels = Seed.bonspiels
        }

        normalized.curlers = normalized.curlers.map { curler in
            var copy = curler
            if copy.importedHistory == nil {
                let hasImportedHistory = copy.record != "0–0" || copy.win != "—" || copy.rinks > 0 || copy.mutual > 0 || !copy.sharedRinks.isEmpty || !copy.form.isEmpty
                if hasImportedHistory {
                    copy.importedHistory = ImportedCurlerHistory(record: copy.record,
                                                                 win: copy.win,
                                                                 rinks: copy.rinks,
                                                                 mutual: copy.mutual,
                                                                 sharedRinks: copy.sharedRinks,
                                                                 form: copy.form)
                }
            }
            return copy
        }

        if normalized.visits.isEmpty {
            normalized.visits = normalized.stops
                .filter { $0.here || !$0.met.isEmpty || $0.record != "—" }
                .map { stop in
                    StopVisit(stopID: stop.id,
                              arrivedAt: stop.dates,
                              departedAt: stop.here ? nil : stop.dates,
                              curlerIDs: stop.met,
                              note: "")
                }
        }

        if normalized.attendance.isEmpty {
            normalized.attendance = normalized.spiels.flatMap { spiel in
                var ids = spiel.going
                if spiel.status == "You're in" { ids.insert("me", at: 0) }
                return ids.map { id in
                    SpielAttendance(spielID: spiel.id,
                                    curlerID: id,
                                    status: .going,
                                    updatedAt: "seed")
                }
            }
        }

        let stopIDs = Set(normalized.stops.map(\.id))
        normalized.spiels = normalized.spiels.map { spiel in
            var copy = spiel
            if let stopID = copy.stopID, !stopIDs.contains(stopID) {
                copy.stopID = nil
            }
            return copy
        }

        let curlerIDs = Set(normalized.curlers.map(\.id) + ["me"])
        let spielIDs = Set(normalized.spiels.map(\.id))

        normalized.visits = normalized.visits
            .filter { stopIDs.contains($0.stopID) }
            .map { visit in
                var copy = visit
                copy.curlerIDs = Array(Set(copy.curlerIDs.filter { curlerIDs.contains($0) })).sorted()
                return copy
            }

        var attendanceSeen = Set<String>()
        normalized.attendance = normalized.attendance.filter { item in
            guard spielIDs.contains(item.spielID), curlerIDs.contains(item.curlerID) else { return false }
            let key = "\(item.spielID)|\(item.curlerID)"
            guard !attendanceSeen.contains(key) else { return false }
            attendanceSeen.insert(key)
            return true
        }

        normalized.bonspiels = normalized.bonspiels
            .filter { spielIDs.contains($0.linkedSpielID) }
            .map { bonspiel in
                var copy = bonspiel
                for teamIndex in copy.teams.indices {
                    for memberIndex in copy.teams[teamIndex].members.indices {
                        if let curlerID = copy.teams[teamIndex].members[memberIndex].curlerID,
                           !curlerIDs.contains(curlerID) {
                            copy.teams[teamIndex].members[memberIndex].curlerID = nil
                        }
                    }
                }

                let stageIDs = Set(copy.stages.map(\.id))
                let teamIDs = Set(copy.teams.map(\.id))
                copy.games = copy.games
                    .filter { stageIDs.contains($0.stageID) && teamIDs.contains($0.teamAID) && teamIDs.contains($0.teamBID) }
                    .map { game in
                        var cleanGame = game
                        cleanGame.gameLineups = cleanGame.gameLineups.compactMap { lineup in
                            guard teamIDs.contains(lineup.teamID),
                                  let team = copy.teams.first(where: { $0.id == lineup.teamID }) else { return nil }
                            let memberIDs = Set(team.members.map(\.id))
                            var cleanLineup = lineup
                            cleanLineup.deliveryRotation = cleanLineup.deliveryRotation.filter { memberIDs.contains($0.memberID) }
                            if let alternate = cleanLineup.alternateMemberID, !memberIDs.contains(alternate) {
                                cleanLineup.alternateMemberID = nil
                            }
                            return cleanLineup.deliveryRotation.isEmpty ? nil : cleanLineup
                        }
                        cleanGame.lineupChanges = cleanGame.lineupChanges.filter { change in
                            teamIDs.contains(change.teamID)
                        }
                        cleanGame.ends = cleanGame.ends.filter { end in
                            end.endNumber > 0
                                && end.teamA >= 0
                                && end.teamB >= 0
                                && !(end.teamA > 0 && end.teamB > 0)
                                && (!end.isBlank || (end.teamA == 0 && end.teamB == 0))
                        }
                        return cleanGame
                    }
                return copy
            }

        let bonspielIDs = Set(normalized.bonspiels.map(\.id))
        let bonspielGameIDs = Set(normalized.bonspiels.flatMap { $0.games.map(\.id) })

        normalized.results = normalized.results.map { result in
            var copy = result
            if let stopID = copy.stopID, !stopIDs.contains(stopID) { copy.stopID = nil }
            if let spielID = copy.spielID, !spielIDs.contains(spielID) { copy.spielID = nil }
            if let bonspielID = copy.bonspielID, !bonspielIDs.contains(bonspielID) { copy.bonspielID = nil }
            if let bonspielGameID = copy.bonspielGameID, !bonspielGameIDs.contains(bonspielGameID) { copy.bonspielGameID = nil }
            copy.participantCurlerIDs = Array(Set(copy.participantCurlerIDs.filter { curlerIDs.contains($0) })).sorted()
            return copy
        }

        return normalized
    }
}

// MARK: - Seed data (mirrors the web build's season)

enum Seed {
    static func appData(setupComplete: Bool) -> AppData {
        AppData(schemaVersion: 4,
                setupComplete: setupComplete,
                profile: .demo,
                curlers: curlers,
                stops: stops,
                visits: visits,
                spiels: spiels,
                attendance: attendance,
                results: results,
                feed: feed,
                bonspiels: bonspiels)
    }

    static let curlers: [Curler] = [
        Curler(id: "sam", initials: "SR", name: "Sam Reid", role: "Skip", club: "Vernon CC", prov: "BC",
               metAt: "Kelowna · Jan 2026", following: false,
               record: "21–9", win: "70%", rinks: 9, mutual: 3,
               sharedRinks: ["Kelowna", "Vernon", "+4 more"],
               form: [GameLine(label: "A-final · Kelowna", score: "8–5", res: "W"),
                      GameLine(label: "Semi · Kelowna", score: "7–6", res: "W")]),
        Curler(id: "jo", initials: "JM", name: "Jo Mara", role: "Lead · Spare", club: "In roster", prov: "BC",
               metAt: "Kelowna · Jan 2026", following: true,
               record: "15–11", win: "58%", rinks: 7, mutual: 5,
               sharedRinks: ["Kelowna", "Kamloops", "+2 more"],
               form: [GameLine(label: "Pool · Kelowna", score: "6–4", res: "W"),
                      GameLine(label: "Tie-break · Vernon", score: "5–7", res: "L")]),
        Curler(id: "dee", initials: "DT", name: "Dee Tan", role: "Lead", club: "Glenmore CC", prov: "BC",
               metAt: "Kelowna · Jan 2026", following: false,
               record: "12–10", win: "55%", rinks: 6, mutual: 2,
               sharedRinks: ["Kelowna", "Glenmore", "+1 more"],
               form: [GameLine(label: "Pool · Kelowna", score: "7–5", res: "W"),
                      GameLine(label: "Pool · Kelowna", score: "4–8", res: "L")]),
        Curler(id: "carter", initials: "BC", name: "Bryn Carter", role: "Skip", club: "Sage Valley CC", prov: "AB",
               metAt: "Kelowna · Jan 2026", following: false,
               record: "18–12", win: "60%", rinks: 8, mutual: 1,
               sharedRinks: ["Kelowna", "Calgary", "+3 more"],
               form: [GameLine(label: "Pool · Kelowna", score: "4–8", res: "L"),
                      GameLine(label: "Final · Calgary", score: "9–7", res: "W")]),
        Curler(id: "lind", initials: "EL", name: "Erik Lindqvist", role: "Third", club: "Granite City CC", prov: "MB",
               metAt: "Kelowna · Jan 2026", following: true,
               record: "24–8", win: "75%", rinks: 11, mutual: 2,
               sharedRinks: ["Kelowna", "Winnipeg", "+5 more"],
               form: [GameLine(label: "Pool · Kelowna", score: "7–5", res: "W"),
                      GameLine(label: "Final · Winnipeg", score: "6–5", res: "W")])
    ]

    static let stops: [Stop] = [
        Stop(id: "kamloops", code: "KAM", name: "Kamloops Cashspiel", club: "Kamloops Curling Club", prov: "BC",
             dates: "FEB 14–16", record: "—", here: false, x: 86, y: 54, big: true,
             iceSpeed: "Fast", iceSpeedSec: "23.6s", iceCurl: "4–5", iceRec: "—",
             games: [], met: []),
        Stop(id: "kelowna", code: "KEL", name: "Kelowna Bonspiel", club: "Kelowna Curling Club", prov: "BC",
             dates: "JAN 9–11", record: "3–1", x: 70, y: 32, plus: "+3",
             iceSpeed: "Fast", iceSpeedSec: "24.1s", iceCurl: "5–6", iceRec: "3–1",
             games: [GameLine(label: "vs Carter", score: "8–4", res: "W"),
                     GameLine(label: "vs Lindqvist", score: "5–7", res: "L")],
             met: ["sam", "jo", "dee"]),
        Stop(id: "vernon", code: "VER", name: "Vernon Cashspiel", club: "Vernon Curling Club", prov: "BC",
             dates: "DEC 2", record: "2–1", x: 50, y: 68, plus: "+2",
             iceSpeed: "Medium", iceSpeedSec: "25.0s", iceCurl: "4–5", iceRec: "2–1",
             games: [GameLine(label: "vs Reid", score: "6–8", res: "L"),
                     GameLine(label: "vs Mara", score: "7–5", res: "W")],
             met: ["sam", "jo"]),
        Stop(id: "calgary", code: "CAL", name: "Sage Valley Open", club: "Sage Valley CC", prov: "AB",
             dates: "NOV 14–16", record: "2–2", x: 30, y: 39,
             iceSpeed: "Keen", iceSpeedSec: "23.2s", iceCurl: "6–7", iceRec: "2–2",
             games: [GameLine(label: "vs Carter", score: "9–7", res: "W"),
                     GameLine(label: "vs Park", score: "4–9", res: "L")],
             met: ["carter"]),
        Stop(id: "winnipeg", code: "WPG", name: "Granite City Classic", club: "Granite City CC", prov: "MB",
             dates: "OCT 24–26", record: "3–0", x: 14, y: 64,
             iceSpeed: "Fast", iceSpeedSec: "24.4s", iceCurl: "5–6", iceRec: "3–0",
             games: [GameLine(label: "vs Lindqvist", score: "6–5", res: "W"),
                     GameLine(label: "vs Olsen", score: "8–3", res: "W")],
             met: ["lind"])
    ]

    static let spiels: [Spiel] = [
        Spiel(id: "sp1", name: "Brier Patch Open", whereText: "Kamloops, BC", whenText: "FEB 14–16",
              status: "You're in", going: ["sam", "jo", "lind"],
              startDate: "2026-02-14", endDate: "2026-02-16", stopID: "kamloops"),
        Spiel(id: "sp2", name: "Okanagan Classic", whereText: "Kelowna, BC", whenText: "MAR 6–8",
              status: "Watching", going: ["dee", "carter"],
              startDate: "2026-03-06", endDate: "2026-03-08", stopID: "kelowna"),
        Spiel(id: "sp3", name: "Prairie Cashspiel", whereText: "Winnipeg, MB", whenText: "MAR 27–29",
              status: "Invite", going: ["lind"],
              startDate: "2026-03-27", endDate: "2026-03-29", stopID: "winnipeg")
    ]

    static let visits: [StopVisit] = [
        StopVisit(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                  stopID: "kamloops",
                  arrivedAt: "FEB 14",
                  departedAt: nil,
                  curlerIDs: [],
                  note: "Active demo visit"),
        StopVisit(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                  stopID: "kelowna",
                  arrivedAt: "JAN 9",
                  departedAt: "JAN 11",
                  curlerIDs: ["sam", "jo", "dee"],
                  note: ""),
        StopVisit(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                  stopID: "vernon",
                  arrivedAt: "DEC 2",
                  departedAt: "DEC 2",
                  curlerIDs: ["sam", "jo"],
                  note: "")
    ]

    static let attendance: [SpielAttendance] = [
        SpielAttendance(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, spielID: "sp1", curlerID: "me", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, spielID: "sp1", curlerID: "sam", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, spielID: "sp1", curlerID: "jo", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!, spielID: "sp1", curlerID: "lind", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, spielID: "sp2", curlerID: "dee", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!, spielID: "sp2", curlerID: "carter", status: .going, updatedAt: "seed"),
        SpielAttendance(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, spielID: "sp3", curlerID: "lind", status: .going, updatedAt: "seed")
    ]

    static let results: [GameResult] = [
        GameResult(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                   authorID: nil,
                   createdAt: "JAN 11",
                   note: "A-final at Kelowna. Ice was lightning all weekend.",
                   opponent: "Northern",
                   scoreFor: 8,
                   scoreAgainst: 5,
                   stopID: "kelowna",
                   spielID: nil,
                   participantCurlerIDs: ["sam", "jo"],
                   ends: [],
                   conceded: false,
                   forfeited: false,
                   locallyConfirmed: true),
        GameResult(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                   authorID: nil,
                   createdAt: "DEC 2",
                   note: "Tie-break at Vernon.",
                   opponent: "Mara",
                   scoreFor: 7,
                   scoreAgainst: 5,
                   stopID: "vernon",
                   spielID: nil,
                   participantCurlerIDs: ["jo"],
                   ends: [],
                   conceded: false,
                   forfeited: false,
                   locallyConfirmed: true)
    ]

    static let bonspiels: [BonspielRecord] = [
        BonspielRecord(
            id: "bon-brier-patch-open",
            linkedSpielID: "sp1",
            name: "Brier Patch Open",
            shortName: "Brier Patch",
            season: "2025-26",
            discipline: .fourPlayer,
            venue: BonspielVenue(name: "Kamloops Curling Club", city: "Kamloops", region: "BC", country: "CA"),
            timezone: "America/Vancouver",
            startDate: "2026-02-14",
            endDate: "2026-02-16",
            registrationWindow: BonspielWindow(opensAt: "2025-11-01", closesAt: "2026-02-01"),
            rulesProfile: BonspielRulesProfile(rulebookRef: "Club bonspiel rules v1",
                                                scheduledEnds: 8,
                                                minEndsForLocalResult: 6,
                                                lsfeMethod: "LSD or coin toss",
                                                tiebreakerMethods: ["Win loss", "Head to head", "Draw shot challenge"]),
            rosterPolicy: BonspielRosterPolicy(maxPlayersOnIce: 4,
                                                allowAlternates: true,
                                                allowSpares: true,
                                                allowReentry: false,
                                                lockMinutesBeforeGame: 45),
            privacyPolicy: BonspielPrivacyPolicy(rosterDisplayFields: ["Team", "Name", "Position", "Club"],
                                                  internalFields: ["Birth date", "Email", "Phone", "Waiver"],
                                                  mediaConsentRequired: false,
                                                  consentVersion: "photo-consent-v1"),
            stages: [
                BonspielStage(id: "bp-pool", name: "Pool A", stageType: "round_robin", sequence: 1),
                BonspielStage(id: "bp-playoff", name: "Playoff", stageType: "bracket", sequence: 2)
            ],
            teams: [
                BonspielTeam(id: "team-mercer", displayName: "Team Mercer", shortName: "Mercer", affiliation: "Calgary Granite CC",
                             members: [
                                BonspielTeamMember(id: "tm-dana", curlerID: nil, displayName: "Dana Mercer", role: "player", rosterStatus: "active", declaredPosition: "Skip"),
                                BonspielTeamMember(id: "tm-jo", curlerID: "jo", displayName: "Jo Mara", role: "player", rosterStatus: "active", declaredPosition: "Third"),
                                BonspielTeamMember(id: "tm-dee", curlerID: "dee", displayName: "Dee Tan", role: "player", rosterStatus: "active", declaredPosition: "Second"),
                                BonspielTeamMember(id: "tm-sam", curlerID: "sam", displayName: "Sam Reid", role: "alternate", rosterStatus: "alternate", declaredPosition: "Lead")
                             ]),
                BonspielTeam(id: "team-carter", displayName: "Team Carter", shortName: "Carter", affiliation: "Sage Valley CC",
                             members: [
                                BonspielTeamMember(id: "tc-bryn", curlerID: "carter", displayName: "Bryn Carter", role: "player", rosterStatus: "active", declaredPosition: "Skip"),
                                BonspielTeamMember(id: "tc-lind", curlerID: "lind", displayName: "Erik Lindqvist", role: "player", rosterStatus: "active", declaredPosition: "Third"),
                                BonspielTeamMember(id: "tc-mara", curlerID: "jo", displayName: "Jo Mara", role: "spare", rosterStatus: "spare", declaredPosition: "Second"),
                                BonspielTeamMember(id: "tc-reid", curlerID: "sam", displayName: "Sam Reid", role: "player", rosterStatus: "active", declaredPosition: "Lead")
                             ])
            ],
            games: [
                BonspielGame(id: "bp-g1",
                             stageID: "bp-pool",
                             drawLabel: "Draw 2",
                             status: .lineupLocked,
                             scheduledStartAt: "2026-02-14 10:00",
                             sheet: "Sheet C",
                             teamAID: "team-mercer",
                             teamBID: "team-carter",
                             stoneColorAssignment: "Team A dark handles",
                             lsfeOrPlacementDecision: BonspielLastStoneDecision(method: "LSD", teamID: "team-mercer", evidence: "Button draw 42.7 cm"),
                             scheduledEnds: 8,
                             minEndsForLocalResult: 6,
                             ends: [
                                BonspielEndScore(id: "bp-g1-e1", endNumber: 1, teamA: 0, teamB: 1, hammerTeamIDStart: "team-mercer", isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
                                BonspielEndScore(id: "bp-g1-e2", endNumber: 2, teamA: 2, teamB: 0, hammerTeamIDStart: "team-mercer", isBlank: false, isExtraEnd: false, measureRequired: true, powerPlayUsed: false),
                                BonspielEndScore(id: "bp-g1-e3", endNumber: 3, teamA: 0, teamB: 0, hammerTeamIDStart: "team-carter", isBlank: true, isExtraEnd: false, measureRequired: false, powerPlayUsed: false),
                                BonspielEndScore(id: "bp-g1-e4", endNumber: 4, teamA: 1, teamB: 0, hammerTeamIDStart: "team-carter", isBlank: false, isExtraEnd: false, measureRequired: false, powerPlayUsed: false)
                             ],
                             gameLineups: [
                                BonspielGameLineup(id: "bp-g1-la",
                                                   teamID: "team-mercer",
                                                   submittedAt: "2026-02-14 09:05",
                                                   source: "game_lineup_form",
                                                   deliveryRotation: [
                                                    BonspielLineupSlot(memberID: "tm-sam", position: "Lead", isSkip: false, isViceSkip: false),
                                                    BonspielLineupSlot(memberID: "tm-dee", position: "Second", isSkip: false, isViceSkip: false),
                                                    BonspielLineupSlot(memberID: "tm-jo", position: "Third", isSkip: false, isViceSkip: true),
                                                    BonspielLineupSlot(memberID: "tm-dana", position: "Fourth", isSkip: true, isViceSkip: false)
                                                   ],
                                                   alternateMemberID: nil,
                                                   coachName: nil),
                                BonspielGameLineup(id: "bp-g1-lb",
                                                   teamID: "team-carter",
                                                   submittedAt: "2026-02-14 09:10",
                                                   source: "same_as_original",
                                                   deliveryRotation: [
                                                    BonspielLineupSlot(memberID: "tc-reid", position: "Lead", isSkip: false, isViceSkip: false),
                                                    BonspielLineupSlot(memberID: "tc-mara", position: "Second", isSkip: false, isViceSkip: false),
                                                    BonspielLineupSlot(memberID: "tc-lind", position: "Third", isSkip: false, isViceSkip: true),
                                                    BonspielLineupSlot(memberID: "tc-bryn", position: "Fourth", isSkip: true, isViceSkip: false)
                                                   ],
                                                   alternateMemberID: nil,
                                                   coachName: nil)
                             ],
                             lineupChanges: [],
                             resultFlags: BonspielResultFlags(isFinal: false, conceded: false, forfeited: false),
                             scoreAgreement: BonspielScoreAgreement(confirmed: false, confirmedAt: nil, confirmedBy: nil),
                             version: 1),
                BonspielGame(id: "bp-g2",
                             stageID: "bp-pool",
                             drawLabel: "Draw 5",
                             status: .scheduled,
                             scheduledStartAt: "2099-02-14 15:00",
                             sheet: "Sheet A",
                             teamAID: "team-mercer",
                             teamBID: "team-carter",
                             stoneColorAssignment: "Team A light handles",
                             lsfeOrPlacementDecision: BonspielLastStoneDecision(method: "LSD pending", teamID: "team-carter", evidence: "Local lineup proof fixture"),
                             scheduledEnds: 8,
                             minEndsForLocalResult: 6,
                             ends: [],
                             gameLineups: [],
                             lineupChanges: [],
                             resultFlags: BonspielResultFlags(isFinal: false, conceded: false, forfeited: false),
                             scoreAgreement: BonspielScoreAgreement(confirmed: false, confirmedAt: nil, confirmedBy: nil),
                             version: 1)
            ],
            version: 1
        ),
        BonspielRecord.defaultLinked(spielID: "sp2",
                                     name: "Okanagan Classic",
                                     whereText: "Kelowna, BC",
                                     whenText: "MAR 6-8",
                                     discipline: .mixed,
                                     homeClub: "Calgary Granite CC",
                                     startDate: "2026-03-06",
                                     endDate: "2026-03-08",
                                     venue: BonspielVenue(name: "Kelowna Curling Club", city: "Kelowna", region: "BC", country: "CA")),
        BonspielRecord.defaultLinked(spielID: "sp3",
                                     name: "Prairie Cashspiel",
                                     whereText: "Winnipeg, MB",
                                     whenText: "MAR 27-29",
                                     discipline: .fourPlayer,
                                     homeClub: "Calgary Granite CC",
                                     startDate: "2026-03-27",
                                     endDate: "2026-03-29",
                                     venue: BonspielVenue(name: "Granite City CC", city: "Winnipeg", region: "MB", country: "CA"),
                                     timezone: "America/Winnipeg")
    ]

    static let feed: [FeedItem] = [
        .spiel(SpielPost(title: "5 curlers you follow are headed to", spielName: "Brier Patch Open",
                         whereText: "KAMLOOPS", whenText: "FEB 14–16", who: ["sam", "jo", "lind"])),
        .review(ReviewPost(author: "jo", time: "5H", rink: "Granite City CC", stars: 4,
                           note: "fast, 5–6 ft of curl"))
    ]
}
