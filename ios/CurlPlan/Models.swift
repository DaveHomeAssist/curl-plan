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

struct Spiel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let whereText: String
    let whenText: String
    var status: String
    var going: [String]
}

struct MeStats { let clubs: Int; let prov: Int; let games: Int; let win: Int }

struct VisitedStop: Identifiable { let stop: Stop; let count: Int; let at: Double; var id: String { stop.id } }

// Navigation routes for the per-tab NavigationStacks.
enum Route: Hashable {
    case stop(String)
    case curler(String)
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
struct IceReadEntry: Identifiable, Codable, Hashable { var id = UUID(); let speed: String; let curl: String; let note: String; let at: Double }
struct ReviewEntry: Identifiable, Codable, Hashable { var id = UUID(); let stars: Int; let note: String; let at: Double }
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

    /// Live telemetry for a real account, computed from their own log (demo keeps seed numbers).
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

    // MARK: Stop-detail contributions

    func visits(_ stopID: String) -> [VisitEntry] { state.visits[stopID] ?? [] }
    func iceReads(_ stopID: String) -> [IceReadEntry] { state.iceReads[stopID] ?? [] }
    func reviews(_ stopID: String) -> [ReviewEntry] { state.reviews[stopID] ?? [] }

    func addVisit(_ stopID: String, date: String, note: String) {
        state.visits[stopID, default: []].insert(VisitEntry(date: date.isEmpty ? "Today" : date, note: note, at: Store.now()), at: 0)
    }
    func addIceRead(_ stopID: String, speed: String, curl: String, note: String) {
        state.iceReads[stopID, default: []].insert(IceReadEntry(speed: speed.isEmpty ? "Medium" : speed, curl: curl, note: note, at: Store.now()), at: 0)
    }
    func addStopReview(_ stopID: String, stars: Int, note: String) {
        state.reviews[stopID, default: []].insert(ReviewEntry(stars: max(1, min(5, stars)), note: note, at: Store.now()), at: 0)
    }

    // MARK: Messaging

    func thread(_ curlerID: String) -> [Message] { state.threads[curlerID] ?? [] }
    func sendMessage(_ curlerID: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        state.threads[curlerID, default: []].append(Message(from: "me", text: t, at: Store.now()))
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
