import SwiftUI

// ============================================================
// CurlPlan — data models + Store.
// Seed baseline lives in Seed.generated.swift (from data/season-seed.json).
// This file owns the mutable demo state layer and the derivations that mirror
// the web Hi-Fi app (index.html). Public credential collection remains disabled
// until the real account backend is configured and verified.
// ============================================================

// MARK: - Value models

struct GameLine: Identifiable, Hashable, Codable {
    var id = UUID()
    let label: String   // opponent or game label
    let score: String   // "8–4"
    let res: String     // "W" / "L"
}

struct Curler: Identifiable, Hashable, Codable {
    let id: String
    let initials: String
    let name: String
    let role: String
    let club: String
    let prov: String
    let metAt: String
    var following: Bool          // seed baseline; live state is Store.isFollowing()
    let record: String
    let win: String
    let clubs: Int
    let mutual: Int
    let sharedClubs: [String]
    let form: [GameLine]
}

struct Stop: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let club: String
    let prov: String
    let dates: String
    let record: String
    var here: Bool = false
    let x: Double
    let y: Double
    var big: Bool = false
    var plus: String? = nil
    let iceSpeed: String
    let iceSpeedSec: String
    let iceCurl: String
    let iceRec: String
    let games: [GameLine]
    let met: [String]
}

struct EventPlanning: Codable, Hashable {
    var format = ""
    var entry = ""
    var organizer = ""
    var draws = ""
    var travel = ""
    var accommodation = ""
    var team = ""

    static let fields: [(String, WritableKeyPath<EventPlanning, String>)] = [
        ("Format", \.format), ("Entry requirements", \.entry), ("Organizer", \.organizer),
        ("Draw schedule", \.draws), ("Travel", \.travel), ("Accommodation", \.accommodation),
        ("Team arrangements", \.team)
    ]
}

struct Spiel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let whereText: String
    var whenText: String
    var status: String
    var going: [String]
    var startAt: Double? = nil
    var endAt: Double? = nil
    var timeZoneID: String? = nil
    var eventKind: String? = nil
    var planning: EventPlanning? = nil
    var preparation: String? = nil
    var at: Double? = nil

    var scheduleLabel: String {
        guard let startAt, let endAt else { return whenText }
        let f = DateFormatter()
        f.timeZone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        f.dateFormat = "MMM d, yyyy h:mm a"
        return f.string(from: Date(timeIntervalSince1970: startAt)) + " – " + f.string(from: Date(timeIntervalSince1970: endAt)) + " · " + (timeZoneID ?? TimeZone.current.identifier)
    }

}

struct MeStats { let clubs: Int; let prov: Int; let games: Int; let win: Int }

struct VisitedStop: Identifiable { let stop: Stop; let count: Int; let at: Double; var id: String { stop.id } }

// Navigation routes for the per-tab NavigationStacks.
enum Route: Hashable, Codable {
    case stop(String)
    case curler(String)

    var url: URL {
        var parts = URLComponents()
        parts.scheme = "curlplan"
        switch self {
        case .stop(let id): parts.host = "stop"; parts.path = "/" + id
        case .curler(let id): parts.host = "curler"; parts.path = "/" + id
        }
        return parts.url!
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == "curlplan", url.query == nil, url.fragment == nil,
              url.user == nil, url.password == nil, url.port == nil else { return nil }
        let ids = url.pathComponents.filter { $0 != "/" }
        guard ids.count == 1, !ids[0].isEmpty else { return nil }
        switch url.host?.lowercased() {
        case "stop": self = .stop(ids[0])
        case "curler": self = .curler(ids[0])
        default: return nil
        }
    }
}

struct MeInfo {
    let name: String
    let initials: String
    let role: String
    let club: String
    let prov: String
    let season: String
    let stats: MeStats
}

// Unified feed post — mirrors the web's uniform dict so seed feed + user posts
// merge trivially and every post carries a stable String id (likes key on it).
struct Post: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case result, note, review, spiel }
    let id: String
    let kind: Kind
    var author: String?
    var at: Double?          // epoch seconds; nil => seed, use `time`
    var time: String?        // seed/legacy relative label
    // result / note
    var body: String?
    var scoreFor: Int?
    var scoreAgainst: Int?
    var res: String?
    var vs: String?
    var likes: Int
    var comments: Int
    // review
    var club: String?
    var stars: Int?
    var note: String?
    // spiel promo
    var title: String?
    var spielName: String?
    var spielId: String?     // links a feed card back to a real Spiel (parity fix)
    var whereText: String?
    var whenText: String?
    var who: [String]?

    init(id: String, kind: Kind, author: String? = nil, at: Double? = nil, time: String? = nil,
         body: String? = nil, scoreFor: Int? = nil, scoreAgainst: Int? = nil, res: String? = nil,
         vs: String? = nil, likes: Int = 0, comments: Int = 0, club: String? = nil, stars: Int? = nil,
         note: String? = nil, title: String? = nil, spielName: String? = nil, spielId: String? = nil,
         whereText: String? = nil, whenText: String? = nil, who: [String]? = nil) {
        self.id = id; self.kind = kind; self.author = author; self.at = at; self.time = time
        self.body = body; self.scoreFor = scoreFor; self.scoreAgainst = scoreAgainst; self.res = res
        self.vs = vs; self.likes = likes; self.comments = comments; self.club = club; self.stars = stars
        self.note = note; self.title = title; self.spielName = spielName; self.spielId = spielId
        self.whereText = whereText; self.whenText = whenText; self.who = who
    }
}

// MARK: - Stop-detail contribution entries + messages

struct VisitEntry: Identifiable, Codable, Hashable { var id = UUID(); let date: String; let note: String; let at: Double }
struct IceReadEntry: Identifiable, Codable, Hashable { var id = UUID(); let speed: String; let curl: String; let note: String; let at: Double; var date: String? = nil; var sheet: String? = nil }
struct ReviewEntry: Identifiable, Codable, Hashable { var id = UUID(); let stars: Int; let note: String; let at: Double }
struct ContributionDraft: Codable, Hashable {
    var visitDate = "Today"
    var date = Date()
    var note = ""
    var speed = "Medium"
    var curl = ""
    var sheet = ""
}

struct EventDraft: Codable, Hashable {
    var name = ""
    var location = ""
    var start = Date()
    var end = Date().addingTimeInterval(7200)
    var kind = "League game"
    var planning: EventPlanning? = nil
    var preparation = ""
    var status = "Going"
    var timeZone = TimeZone.current.identifier
}

struct ReviewDraft: Codable, Hashable { var stars = 5; var note = "" }
struct Message: Identifiable, Codable, Hashable { var id = UUID(); let from: String; let text: String; let at: Double }

// MARK: - Identity

struct Account: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let club: String
    let role: String
    let prov: String
    var isDemo: Bool { id == "demo" }

    static let demo = Account(id: "demo", name: Seed.me.name,
                              club: Seed.me.club, role: Seed.me.role, prov: Seed.me.prov)
}

struct AuthState: Codable {
    var session: String? = nil     // "demo" | nil
}

// Composer drafts are private local state, separate from published posts.
struct PostDraft: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable { case note = "Note", result = "Result", review = "Review" }
    var kind: Kind = .note
    var body = ""
    var opponent = ""
    var scoreFor = ""
    var scoreAgainst = ""
    var club = ""
    var stars = 5
    var note = ""

    init() {}
    init(post: Post) {
        kind = post.kind == .result ? .result : post.kind == .review ? .review : .note
        body = post.body ?? ""
        opponent = post.vs ?? ""
        if opponent.lowercased().hasPrefix("vs ") { opponent = String(opponent.dropFirst(3)) }
        scoreFor = post.scoreFor.map(String.init) ?? ""
        scoreAgainst = post.scoreAgainst.map(String.init) ?? ""
        club = post.club ?? ""
        stars = post.stars ?? 5
        note = post.note ?? ""
    }

    var isValid: Bool {
        switch kind {
        case .note: return !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .review: return !club.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...5).contains(stars)
        case .result:
            guard let f = Int(scoreFor.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let a = Int(scoreAgainst.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            return f >= 0 && a >= 0
        }
    }
}

// MARK: - Per-account mutable state (the "store" blob)

struct AppState: Codable, Hashable {
    var addedCurlers: [Curler] = []
    var addedSpiels: [Spiel] = []
    var follows: [String: Bool] = [:]        // curlerId -> override
    var likes: [String: Bool] = [:]          // postId -> liked
    var joins: [String: String] = [:]        // spielId -> status override
    var posts: [Post] = []                   // user-authored, newest first
    var visits: [String: [VisitEntry]] = [:] // stopId -> entries
    var reviews: [String: [ReviewEntry]] = [:]
    var iceReads: [String: [IceReadEntry]] = [:]
    var threads: [String: [Message]] = [:]   // curlerId -> messages
    var messageDrafts: [String: String] = [:]
    var reviewDrafts: [String: ReviewDraft] = [:]
    // Optional keeps backups created before event drafts valid without rewriting them.
    var contributionDrafts: [String: ContributionDraft]? = nil
    var eventDrafts: [String: EventDraft]? = nil
    var postDrafts: [String: PostDraft] = [:] // "new" or the owned post ID
    var tombstones: [String: [String: Double]] = [:]

    init() {}

    // Tolerant decode: property defaults apply for missing/new keys, so adding a bucket
    // in a later version never wipes an existing account's saved state (web-parity resilience).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // try? flattens the optional from decodeIfPresent, so a single bind is correct.
        if let v = try? c.decodeIfPresent([Curler].self, forKey: .addedCurlers) { addedCurlers = v }
        if let v = try? c.decodeIfPresent([Spiel].self, forKey: .addedSpiels) { addedSpiels = v }
        if let v = try? c.decodeIfPresent([String: Bool].self, forKey: .follows) { follows = v }
        if let v = try? c.decodeIfPresent([String: Bool].self, forKey: .likes) { likes = v }
        if let v = try? c.decodeIfPresent([String: String].self, forKey: .joins) { joins = v }
        if let v = try? c.decodeIfPresent([Post].self, forKey: .posts) { posts = v }
        if let v = try? c.decodeIfPresent([String: [VisitEntry]].self, forKey: .visits) { visits = v }
        if let v = try? c.decodeIfPresent([String: [ReviewEntry]].self, forKey: .reviews) { reviews = v }
        if let v = try? c.decodeIfPresent([String: [IceReadEntry]].self, forKey: .iceReads) { iceReads = v }
        if let v = try? c.decodeIfPresent([String: [Message]].self, forKey: .threads) { threads = v }
        if let v = try? c.decodeIfPresent([String: String].self, forKey: .messageDrafts) { messageDrafts = v }
        if let v = try? c.decodeIfPresent([String: ReviewDraft].self, forKey: .reviewDrafts) { reviewDrafts = v }
        contributionDrafts = try? c.decodeIfPresent([String: ContributionDraft].self, forKey: .contributionDrafts)
        eventDrafts = try? c.decodeIfPresent([String: EventDraft].self, forKey: .eventDrafts)
        if let v = try? c.decodeIfPresent([String: PostDraft].self, forKey: .postDrafts) { postDrafts = v }
        if let v = try? c.decodeIfPresent([String: [String: Double]].self, forKey: .tombstones) { tombstones = v }
    }
}

// MARK: - Time helpers (mirror web fmtAgo / fmtTime)

enum RelativeTime {
    static func ago(_ at: Double) -> String {
        let s = Int(Date().timeIntervalSince1970 - at)
        if s < 60 { return "NOW" }
        let m = s / 60; if m < 60 { return "\(m)M" }
        let h = m / 60; if h < 24 { return "\(h)H" }
        let d = h / 24; if d < 7 { return "\(d)D" }
        let df = DateFormatter(); df.dateFormat = "MMM d"
        return df.string(from: Date(timeIntervalSince1970: at)).uppercased()
    }
    static func clock(_ at: Double) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: Date(timeIntervalSince1970: at))
    }
}

// MARK: - Store

final class Store: ObservableObject {
    @Published private(set) var auth: AuthState { didSet { persistAuth() } }
    @Published private(set) var state: AppState { didSet { persistState() } }

    private static let authKey = "cp.auth.v1"
    private var stateKey: String { "cp.state.v2:" + (auth.session ?? "anon") }

    /// Persistence backing store — override with an ephemeral suite in tests.
    static var defaults: UserDefaults = .standard

    init() {
        let loadedAuth = Store.loadAuth(Store.authKey)
        auth = loadedAuth
        // one-time migrate the pre-parity global blobs into the demo bucket
        Store.migrateLegacyIfNeeded(session: loadedAuth.session)
        state = Store.loadState(key: "cp.state.v2:" + (loadedAuth.session ?? "anon"))
    }

    // MARK: Baselines (immutable seed) + derived collections

    var stops: [Stop] { Seed.stops }
    var curlers: [Curler] { state.addedCurlers + Seed.curlers }
    var spiels: [Spiel] { state.addedSpiels + Seed.spiels }
    var allPosts: [Post] { state.posts + Seed.feed }

    func curler(_ id: String) -> Curler? { curlers.first { $0.id == id } }
    func stop(_ id: String) -> Stop? { stops.first { $0.id == id } }
    func spiel(_ id: String) -> Spiel? { spiels.first { $0.id == id } }

    var recentStops: [Stop] { Seed.recentStopIDs.compactMap { stop($0) } }

    /// Demo map pins that represent completed stops. The `here` seed entry is
    /// an explicit sample-location cue, so it must not inflate logged totals.
    var demoLoggedStops: [Stop] { stops.filter { !$0.here } }

    // MARK: Identity

    func currentUser() -> Account? {
        auth.session == "demo" ? .demo : nil
    }
    var isSignedIn: Bool { auth.session != nil }
    var isRealAccount: Bool { false }
    var me: MeInfo { Seed.me }

    /// Personal telemetry comes only from the current local log, including demo additions.
    func derivedStats() -> MeStats {
        let visitedIds = state.visits.filter { !$0.value.isEmpty }.map { $0.key }
        var provs = Set<String>()
        for sid in visitedIds { if let s = stop(sid) { provs.insert(s.prov) } }
        let results = state.posts.filter { $0.kind == .result }
        let games = results.count
        let wins = results.filter { $0.res == "WIN" }.count
        let win = games > 0 ? Int((Double(wins) * 100 / Double(games)).rounded()) : 0
        return MeStats(clubs: visitedIds.count, prov: provs.count, games: games, win: win)
    }

    /// Stops the user has actually logged a visit at, newest visit first.
    func visitedStops() -> [VisitedStop] {
        state.visits.compactMap { (sid, entries) -> VisitedStop? in
            guard !entries.isEmpty, let s = stop(sid) else { return nil }
            let latest = entries.map { $0.at }.max() ?? 0
            return VisitedStop(stop: s, count: entries.count, at: latest)
        }
        .sorted { $0.at > $1.at }
    }

    // MARK: Follow graph

    func isFollowing(_ id: String) -> Bool {
        if let o = state.follows[id] { return o }
        return curler(id)?.following ?? false
    }
    func toggleFollow(_ id: String) { state.follows[id] = !isFollowing(id) }

    // MARK: Likes

    func isLiked(_ postId: String) -> Bool { state.likes[postId] ?? false }
    func likeCount(_ p: Post) -> Int { p.likes + (isLiked(p.id) ? 1 : 0) }
    func toggleLike(_ postId: String) { state.likes[postId] = !isLiked(postId) }

    // MARK: Spiel registration (unified across Spiels tab + feed)

    func spielStatus(_ id: String) -> String { state.joins[id] ?? (spiel(id)?.status ?? "Watching") }
    func setSpielStatus(_ id: String, _ status: String) { state.joins[id] = status }
    func withdrawSpiel(_ id: String) {
        if spiel(id)?.status == "You're in" { state.joins[id] = "Watching" }
        else { state.joins[id] = nil }
    }

    // MARK: Create actions (write to the per-account state)

    func upcomingEvents(now: Double = Store.now()) -> [Spiel] {
        state.addedSpiels.filter { ($0.endAt ?? -1) >= now && spielStatus($0.id) != "Not going" }
            .sorted { ($0.startAt ?? 0) < ($1.startAt ?? 0) }
    }

    func eventConflicts(start: Double, end: Double, excluding id: String? = nil) -> [Spiel] {
        state.addedSpiels.filter {
            $0.id != id && spielStatus($0.id) != "Not going" &&
            ($0.startAt ?? .infinity) < end && ($0.endAt ?? -.infinity) > start
        }
    }

    func saveEventDraft(_ draft: EventDraft, editingID: String? = nil) {
        guard isSignedIn else { return }
        var drafts = state.eventDrafts ?? [:]
        drafts[editingID ?? "new"] = draft
        state.eventDrafts = drafts
    }

    func discardEventDraft(editingID: String? = nil) {
        state.eventDrafts?.removeValue(forKey: editingID ?? "new")
        if state.eventDrafts?.isEmpty == true { state.eventDrafts = nil }
    }

    @discardableResult
    func saveScheduledEvent(id: String? = nil, name: String, location: String, start: Double, end: Double,
                            timeZone: String, kind: String, preparation: String, status: String, planning: EventPlanning? = nil) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !location.isEmpty, start.isFinite, end.isFinite, end > start,
              TimeZone(identifier: timeZone) != nil,
              ["League game", "Practice", "Bonspiel", "Event"].contains(kind),
              ["Going", "Considering", "Not going"].contains(status) else { return false }
        let existing = id.flatMap { target in state.addedSpiels.first { $0.id == target } }
        if id != nil && existing == nil { return false }
        var event = Spiel(id: id ?? Store.uid("sp"), name: name, whereText: location,
                          whenText: "", status: status, going: existing?.going ?? [])
        event.startAt = start; event.endAt = end; event.timeZoneID = timeZone
        event.planning = planning ?? existing?.planning
        event.eventKind = kind; event.preparation = preparation
        event.at = max(Store.now(), (existing?.at ?? 0) + 0.001)
        event.whenText = event.scheduleLabel
        if let index = state.addedSpiels.firstIndex(where: { $0.id == event.id }) { state.addedSpiels[index] = event }
        else { state.addedSpiels.insert(event, at: 0) }
        state.joins[event.id] = status
        discardEventDraft(editingID: id)
        return true
    }

    @discardableResult
    func deleteScheduledEvent(_ id: String) -> Bool {
        guard let event = state.addedSpiels.first(where: { $0.id == id }) else { return false }
        state.addedSpiels.removeAll { $0.id == id }
        state.joins[id] = nil
        discardEventDraft(editingID: id)
        state.tombstones["addedSpiels", default: [:]][id] = max(Store.now(), (event.at ?? 0) + 0.001)
        return true
    }

    @discardableResult
    func addSpiel(name: String, whereText: String, whenText: String, status: String) -> Spiel {
        let sp = Spiel(id: Store.uid("sp"), name: name,
                       whereText: whereText.isEmpty ? "TBD" : whereText,
                       whenText: whenText.isEmpty ? "DATE TBD" : whenText,
                       status: status, going: [])
        state.addedSpiels.insert(sp, at: 0)
        return sp
    }

    @discardableResult
    func addCurler(name: String, role: String, club: String, prov: String) -> Curler {
        let initials = Store.initials(name)
        let c = Curler(id: Store.uid("c"), initials: initials.isEmpty ? "?" : initials,
                       name: name, role: role.isEmpty ? "Curler" : role,
                       club: club.isEmpty ? "—" : club, prov: prov.isEmpty ? "—" : prov,
                       metAt: "your roster", following: true,
                       record: "0–0", win: "—", clubs: 0, mutual: 0, sharedClubs: [], form: [])
        state.addedCurlers.insert(c, at: 0)
        return c
    }

    func addResult(body: String, scoreFor: Int, scoreAgainst: Int, vs: String) {
        let res = scoreFor == scoreAgainst ? "TIE" : (scoreFor > scoreAgainst ? "WIN" : "LOSS")
        let opp = vs.trimmingCharacters(in: .whitespaces)
        let vsLabel = opp.isEmpty ? "" : (opp.lowercased().hasPrefix("vs") ? opp : "vs \(opp)")
        let p = Post(id: Store.uid("p"), kind: .result, author: "me", at: Store.now(),
                     body: body, scoreFor: scoreFor, scoreAgainst: scoreAgainst, res: res,
                     vs: vsLabel, likes: 0, comments: 0)
        state.posts.insert(p, at: 0)
    }

    func addNote(body: String) {
        let p = Post(id: Store.uid("p"), kind: .note, author: "me", at: Store.now(), body: body)
        state.posts.insert(p, at: 0)
    }

    func addReview(club: String, stars: Int, note: String) {
        let p = Post(id: Store.uid("p"), kind: .review, author: "me", at: Store.now(),
                     club: club, stars: max(1, min(5, stars)), note: note)
        state.posts.insert(p, at: 0)
    }

    // MARK: Owned posts and drafts

    func canEditPost(_ id: String) -> Bool {
        !Seed.feed.contains { $0.id == id } && state.posts.contains {
            $0.id == id && $0.author == "me" && $0.kind != .spiel
        }
    }

    func savePostDraft(_ draft: PostDraft, editingID: String? = nil) {
        guard currentUser() != nil, editingID.map(canEditPost) ?? true else { return }
        state.postDrafts[editingID ?? "new"] = draft
    }

    func discardPostDraft(editingID: String? = nil) {
        state.postDrafts.removeValue(forKey: editingID ?? "new")
    }

    @discardableResult
    func savePost(_ draft: PostDraft, editingID: String? = nil) -> Bool {
        guard currentUser() != nil, draft.isValid else { return false }
        if let id = editingID, !canEditPost(id) { return false }
        let kind: Post.Kind = draft.kind == .note ? .note : draft.kind == .result ? .result : .review
        let existing = editingID.flatMap { id in state.posts.first { $0.id == id } }
        if let existing, existing.kind != kind { return false }
        var post = existing ?? Post(id: Store.uid("p"), kind: kind, author: "me")
        post.at = max(Store.now(), (existing?.at ?? 0).nextUp)
        post.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == .result {
            guard let f = Int(draft.scoreFor.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let a = Int(draft.scoreAgainst.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            post.scoreFor = f; post.scoreAgainst = a
            post.res = f == a ? "TIE" : f > a ? "WIN" : "LOSS"
            let opponent = draft.opponent.trimmingCharacters(in: .whitespacesAndNewlines)
            post.vs = opponent.isEmpty ? "" : "vs \(opponent)"
        } else if kind == .review {
            post.club = draft.club.trimmingCharacters(in: .whitespacesAndNewlines)
            post.stars = draft.stars
            post.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var next = state
        if let index = next.posts.firstIndex(where: { $0.id == post.id }) {
            next.posts[index] = post
        } else { next.posts.insert(post, at: 0) }
        next.postDrafts.removeValue(forKey: editingID ?? "new")
        state = next
        return true
    }

    @discardableResult
    func deletePost(_ id: String) -> Bool {
        guard canEditPost(id), let post = state.posts.first(where: { $0.id == id }) else { return false }
        var next = state
        next.tombstones["posts", default: [:]][id] = max(Store.now(), post.at ?? 0)
        next.posts.removeAll { $0.id == id }
        next.likes.removeValue(forKey: id)
        next.postDrafts.removeValue(forKey: id)
        state = next
        return true
    }

    // MARK: Stop-detail contributions

    func visits(_ stopID: String) -> [VisitEntry] { state.visits[stopID] ?? [] }
    func iceReads(_ stopID: String) -> [IceReadEntry] { state.iceReads[stopID] ?? [] }
    func reviews(_ stopID: String) -> [ReviewEntry] { state.reviews[stopID] ?? [] }

    func contributionDraftKey(_ stopID: String, kind: String) -> String { kind + ":" + stopID }

    func saveContributionDraft(_ stopID: String, kind: String, draft: ContributionDraft) {
        guard isSignedIn, stop(stopID) != nil, ["visit", "ice"].contains(kind) else { return }
        var drafts = state.contributionDrafts ?? [:]
        drafts[contributionDraftKey(stopID, kind: kind)] = draft
        state.contributionDrafts = drafts
    }

    func discardContributionDraft(_ stopID: String, kind: String) {
        state.contributionDrafts?.removeValue(forKey: contributionDraftKey(stopID, kind: kind))
        if state.contributionDrafts?.isEmpty == true { state.contributionDrafts = nil }
    }

    func addVisit(_ stopID: String, date: String, note: String) {
        state.visits[stopID, default: []].insert(VisitEntry(date: date.isEmpty ? "Today" : date, note: note, at: Store.now()), at: 0)
        discardContributionDraft(stopID, kind: "visit")
    }
    func addIceRead(_ stopID: String, speed: String, curl: String, note: String, date: String? = nil, sheet: String? = nil) {
        state.iceReads[stopID, default: []].insert(IceReadEntry(speed: speed.isEmpty ? "Medium" : speed, curl: curl, note: note, at: Store.now(), date: date, sheet: sheet?.trimmingCharacters(in: .whitespacesAndNewlines)), at: 0)
        discardContributionDraft(stopID, kind: "ice")
    }
    func addStopReview(_ stopID: String, stars: Int, note: String) {
        state.reviews[stopID, default: []].insert(ReviewEntry(stars: max(1, min(5, stars)), note: note, at: Store.now()), at: 0)
    }

    func reviewDraftKey(_ stopID: String, editingID: UUID? = nil) -> String {
        "\(stopID):\(editingID?.uuidString ?? "new")"
    }

    func saveReviewDraft(_ stopID: String, draft: ReviewDraft, editingID: UUID? = nil) {
        guard currentUser() != nil, stop(stopID) != nil else { return }
        if let id = editingID, !reviews(stopID).contains(where: { $0.id == id }) { return }
        state.reviewDrafts[reviewDraftKey(stopID, editingID: editingID)] = draft
    }

    func discardReviewDraft(_ stopID: String, editingID: UUID? = nil) {
        state.reviewDrafts.removeValue(forKey: reviewDraftKey(stopID, editingID: editingID))
    }

    @discardableResult
    func saveReview(_ stopID: String, draft: ReviewDraft, editingID: UUID? = nil) -> Bool {
        guard currentUser() != nil, stop(stopID) != nil, (1...5).contains(draft.stars) else { return false }
        let existing = editingID.flatMap { id in reviews(stopID).first { $0.id == id } }
        if editingID != nil && existing == nil { return false }
        let review = ReviewEntry(id: existing?.id ?? UUID(), stars: draft.stars,
                                 note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                                 at: max(Store.now(), (existing?.at ?? 0).nextUp))
        var next = state
        if let index = next.reviews[stopID]?.firstIndex(where: { $0.id == review.id }) {
            next.reviews[stopID]?[index] = review
        } else { next.reviews[stopID, default: []].insert(review, at: 0) }
        next.reviewDrafts.removeValue(forKey: reviewDraftKey(stopID, editingID: editingID))
        state = next
        return true
    }

    @discardableResult
    func deleteReview(_ stopID: String, id: UUID) -> Bool {
        guard currentUser() != nil, let review = reviews(stopID).first(where: { $0.id == id }) else { return false }
        var next = state
        next.reviews[stopID]?.removeAll { $0.id == id }
        next.tombstones["reviews", default: [:]][id.uuidString] = max(Store.now(), review.at)
        next.reviewDrafts.removeValue(forKey: reviewDraftKey(stopID, editingID: id))
        state = next
        return true
    }

    // MARK: Messaging

    func thread(_ curlerID: String) -> [Message] { state.threads[curlerID] ?? [] }
    func sendMessage(_ curlerID: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var next = state
        next.threads[curlerID, default: []].append(Message(from: "me", text: t, at: Store.now()))
        next.messageDrafts.removeValue(forKey: curlerID)
        state = next
    }

    func saveMessageDraft(_ curlerID: String, text: String) {
        guard currentUser() != nil, curler(curlerID) != nil else { return }
        if text.isEmpty { state.messageDrafts.removeValue(forKey: curlerID) }
        else { state.messageDrafts[curlerID] = text }
    }

    // MARK: Demo session

    func exploreDemo() {
        setSession("demo")
    }

    func signOut() { setSession(nil) }

    /// Switch identity: persist current, repoint the key, load that account's state.
    private func setSession(_ session: String?) {
        auth.session = session
        state = Store.loadState(key: stateKey)
    }

    // MARK: Persistence

    func backupData() throws -> Data {
        guard let account = auth.session else { throw BackupError.invalid }
        let data = try JSONEncoder().encode(LocalBackup(account: account, state: state))
        guard data.count <= 5_000_000 else { throw BackupError.invalid }
        return data
    }

    func previewBackup(_ data: Data) throws -> LocalBackup {
        guard let account = auth.session else { throw BackupError.invalid }
        return try LocalBackup.validate(data, account: account)
    }

    func restoreBackup(_ data: Data) throws {
        let backup = try previewBackup(data)
        let previous = try backupData()
        Store.defaults.set(previous, forKey: stateKey + ":beforeRestore")
        guard Store.defaults.data(forKey: stateKey + ":beforeRestore") == previous else { throw BackupError.invalid }
        state = backup.state
    }

    var recoveryBackup: Data? { Store.defaults.data(forKey: stateKey + ":beforeRestore") }

    private func persistAuth() {
        if let d = try? JSONEncoder().encode(auth) { Store.defaults.set(d, forKey: Store.authKey) }
    }
    private func persistState() {
        if let d = try? JSONEncoder().encode(state) { Store.defaults.set(d, forKey: stateKey) }
    }
    private static func loadAuth(_ key: String) -> AuthState {
        guard let d = Store.defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AuthState.self, from: d) else { return AuthState() }
        let sanitized = AuthState(session: decoded.session == "demo" ? "demo" : nil)
        if let replacement = try? JSONEncoder().encode(sanitized) {
            Store.defaults.set(replacement, forKey: key)
        }
        return sanitized
    }
    private static func loadState(key: String) -> AppState {
        guard let d = Store.defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(AppState.self, from: d) else { return AppState() }
        return s
    }

    /// Migrate the pre-parity global arrays (cp.curlers/spiels/feed.v1) into the demo bucket,
    /// once. Best-effort: seed items are dropped; only user additions carry over.
    private static func migrateLegacyIfNeeded(session: String?) {
        let d = Store.defaults
        let demoKey = "cp.state.v2:demo"
        guard d.data(forKey: demoKey) == nil else { return }
        let hadLegacy = d.data(forKey: "cp.curlers.v1") != nil
            || d.data(forKey: "cp.spiels.v1") != nil
            || d.data(forKey: "cp.feed.v1") != nil
        guard hadLegacy else { return }
        var migrated = AppState()
        let seedCurlerIDs = Set(Seed.curlers.map { $0.id })
        let seedSpielIDs = Set(Seed.spiels.map { $0.id })
        if let cd = d.data(forKey: "cp.curlers.v1"), let cs = try? JSONDecoder().decode([Curler].self, from: cd) {
            migrated.addedCurlers = cs.filter { !seedCurlerIDs.contains($0.id) }
        }
        if let sd = d.data(forKey: "cp.spiels.v1"), let ss = try? JSONDecoder().decode([Spiel].self, from: sd) {
            migrated.addedSpiels = ss.filter { !seedSpielIDs.contains($0.id) }
        }
        // Legacy feed used a different (enum) shape; new Post won't decode it — safe to drop.
        if let data = try? JSONEncoder().encode(migrated) { d.set(data, forKey: demoKey) }
        d.removeObject(forKey: "cp.curlers.v1")
        d.removeObject(forKey: "cp.spiels.v1")
        d.removeObject(forKey: "cp.feed.v1")
    }

    // MARK: Utilities

    static func now() -> Double { Date().timeIntervalSince1970 }
    static func uid(_ prefix: String) -> String { prefix + "-" + UUID().uuidString.prefix(8).lowercased() }
    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = parts.first?.first else { return "··" }
        let last = parts.count > 1 ? (parts.last?.first).map(String.init) ?? "" : ""
        return (String(first) + last).uppercased()
    }
}

// Versioned, app-specific backups. Public account credentials and preferences are excluded.
enum BackupError: LocalizedError {
    case invalid
    var errorDescription: String? { "This is not a supported CurlPlan iOS backup for the current account, or its records are invalid. Nothing was restored." }
}

struct LocalBackup: Codable {
    var format = "curlplan-ios"
    var version = 1
    let account: String
    var createdAt = Date()
    let state: AppState

    var summary: String {
        let visits = state.visits.values.reduce(0) { $0 + $1.count }
        let ice = state.iceReads.values.reduce(0) { $0 + $1.count }
        let reviews = state.reviews.values.reduce(0) { $0 + $1.count }
        let messages = state.threads.values.reduce(0) { $0 + $1.count }
        let drafts = state.postDrafts.count + state.reviewDrafts.count + state.messageDrafts.count + (state.eventDrafts?.count ?? 0) + (state.contributionDrafts?.count ?? 0)
        return "\(state.posts.count) posts · \(visits) visits · \(ice) ice readings · \(reviews) reviews · \(messages) messages · \(drafts) drafts · \(state.addedSpiels.count) events · \(state.addedCurlers.count) curlers"
    }

    static func validate(_ data: Data, account: String) throws -> LocalBackup {
        guard data.count <= 5_000_000 else { throw BackupError.invalid }
        do {
            let backup = try JSONDecoder().decode(LocalBackup.self, from: data)
            guard backup.format == "curlplan-ios", backup.version == 1, backup.account == account else { throw BackupError.invalid }
            // AppState's normal decoder tolerates old local data. Restore must reject
            // anything it would drop, default, or silently coerce instead.
            let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
            let roundTrip = try JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? NSDictionary
            guard original == roundTrip else { throw BackupError.invalid }
            for post in backup.state.posts where post.kind == .result {
                guard let f = post.scoreFor, let a = post.scoreAgainst, f >= 0, a >= 0,
                      post.res == (f > a ? "WIN" : f < a ? "LOSS" : "TIE") else { throw BackupError.invalid }
            }
            for event in backup.state.addedSpiels where event.startAt != nil || event.endAt != nil {
                guard let start = event.startAt, let end = event.endAt, start.isFinite, end.isFinite, end > start,
                      let zone = event.timeZoneID, TimeZone(identifier: zone) != nil,
                      let kind = event.eventKind, ["League game", "Practice", "Bonspiel", "Event"].contains(kind) else { throw BackupError.invalid }
            }
            for draft in (backup.state.eventDrafts ?? [:]).values {
                guard draft.end >= draft.start, TimeZone(identifier: draft.timeZone) != nil,
                      ["League game", "Practice", "Bonspiel", "Event"].contains(draft.kind),
                      ["Going", "Considering", "Not going"].contains(draft.status) else { throw BackupError.invalid }
            }
            for reviews in backup.state.reviews.values {
                guard reviews.allSatisfy({ (1...5).contains($0.stars) }) else { throw BackupError.invalid }
            }
            guard Set(backup.state.posts.map(\.id)).count == backup.state.posts.count else { throw BackupError.invalid }
            return backup
        } catch { throw BackupError.invalid }
    }
}
