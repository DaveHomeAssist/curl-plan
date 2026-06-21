import SwiftUI

// MARK: - Models

struct GameLine: Identifiable, Hashable {
    let id = UUID()
    let label: String   // opponent or game label
    let score: String   // "8–4"
    let res: String     // "W" / "L"
}

struct Curler: Identifiable, Hashable {
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
    let x: Double           // 0–100 % position on the season map
    let y: Double
    var big: Bool = false
    var plus: String? = nil // "+3" badge on the avatar stack
    let iceSpeed: String
    let iceSpeedSec: String
    let iceCurl: String
    let iceRec: String
    let games: [GameLine]
    let met: [String]       // curler ids
}

struct ResultPost: Identifiable {
    let id = UUID()
    let author: String, time: String, body: String
    let scoreFor: Int, scoreAgainst: Int, res: String, vs: String
    let likes: Int, comments: Int
}

struct SpielPost: Identifiable {
    let id = UUID()
    let title: String, spielName: String, whereText: String, whenText: String
    let who: [String]
}

struct ReviewPost: Identifiable {
    let id = UUID()
    let author: String, time: String, rink: String
    let stars: Int, note: String
}

enum FeedItem: Identifiable {
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

struct Spiel: Identifiable, Hashable {
    let id: String
    let name: String
    let whereText: String
    let whenText: String
    let status: String
    let going: [String]
}

// Navigation routes for the per-tab NavigationStacks.
enum Route: Hashable {
    case stop(String)
    case curler(String)
}

// MARK: - Store

final class Store: ObservableObject {
    @Published var curlers: [Curler] = Seed.curlers
    @Published var stops: [Stop] = Seed.stops
    @Published var spiels: [Spiel] = Seed.spiels
    let feed: [FeedItem] = Seed.feed
    let me = Me()

    struct Me {
        let name = "Dana Mercer"
        let initials = "DM"
        let season = "Season 2025–26 · in progress"
        let rinks = 12
        let prov = 4
        let games = 38
        let win = 68
    }

    func curler(_ id: String) -> Curler? { curlers.first(where: { $0.id == id }) }
    func stop(_ id: String) -> Stop? { stops.first(where: { $0.id == id }) }

    var recentStops: [Stop] {
        ["kelowna", "vernon"].compactMap { id in stops.first(where: { $0.id == id }) }
    }

    func isFollowing(_ id: String) -> Bool { curler(id)?.following ?? false }

    func toggleFollow(_ id: String) {
        guard let i = curlers.firstIndex(where: { $0.id == id }) else { return }
        curlers[i].following.toggle()
    }
}

// MARK: - Seed data (mirrors the web build's season)

enum Seed {
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
             dates: "HERE NOW", record: "—", here: true, x: 86, y: 54, big: true,
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
              status: "You're in", going: ["sam", "jo", "lind"]),
        Spiel(id: "sp2", name: "Okanagan Classic", whereText: "Kelowna, BC", whenText: "MAR 6–8",
              status: "Watching", going: ["dee", "carter"]),
        Spiel(id: "sp3", name: "Prairie Cashspiel", whereText: "Winnipeg, MB", whenText: "MAR 27–29",
              status: "Invite", going: ["lind"])
    ]

    static let feed: [FeedItem] = [
        .result(ResultPost(author: "sam", time: "2H",
                           body: "Took the A-final at Kelowna. Ice was lightning all weekend. 🥌",
                           scoreFor: 8, scoreAgainst: 5, res: "WIN", vs: "vs Northern",
                           likes: 24, comments: 6)),
        .spiel(SpielPost(title: "5 curlers you follow are headed to", spielName: "Brier Patch Open",
                         whereText: "KAMLOOPS", whenText: "FEB 14–16", who: ["sam", "jo", "lind"])),
        .review(ReviewPost(author: "jo", time: "5H", rink: "Granite City CC", stars: 4,
                           note: "fast, 5–6 ft of curl"))
    ]
}
