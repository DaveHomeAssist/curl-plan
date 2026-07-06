import Foundation

// ============================================================
// Merge.swift — Swift port of src/merge.js (sync schema v3 CRDT merge).
// Operates on a generic JSON value so it is cross-tested against the SAME
// data/merge-fixtures.json the JS reference uses (see MergeTests.swift).
// Pure, commutative, idempotent, associative → convergent sync.
//
// Not yet wired into the live Store — that happens in Phase C of the unified
// backend (docs/UNIFIED_BACKEND_FRAMEWORK.md). This proves the algebra matches
// the web/server implementation byte-for-byte on the shared fixtures.
// ============================================================

indirect enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    var asObject: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    var asArray: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    var asNumber: Double? { if case .number(let n) = self { return n }; return nil }
    var asString: String? { if case .string(let s) = self { return s }; return nil }
    subscript(_ key: String) -> JSONValue? { asObject?[key] }

    // Canonical, key-sorted serialization for deterministic tie-breaks (mirrors JS stableStringify).
    func stableString() -> String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return JSONValue.num(n)
        case .string(let s): return JSONValue.quote(s)
        case .array(let a): return "[" + a.map { $0.stableString() }.joined(separator: ",") + "]"
        case .object(let o): return "{" + o.keys.sorted().map { JSONValue.quote($0) + ":" + o[$0]!.stableString() }.joined(separator: ",") + "}"
        }
    }
    private static func num(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e15 { return String(Int64(n)) }
        return String(n)
    }
    private static func quote(_ s: String) -> String {
        var out = "\""
        for c in s {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(c)
            }
        }
        return out + "\""
    }
}

extension JSONValue: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unrecognized JSON value")
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

enum Merge {
    static let lwwMaps = ["follows", "likes", "joins"]
    static let orsetLists = ["posts", "addedCurlers", "addedSpiels"]
    static let orsetMapLists = ["visits", "reviews", "iceReads", "threads"]

    // LWW: later `at` wins; tie → larger stable-stringified value (symmetric).
    static func pickLWW(_ x: JSONValue?, _ y: JSONValue?) -> JSONValue {
        guard let x = x else { return y ?? .null }
        guard let y = y else { return x }
        let ax = x["at"]?.asNumber ?? 0, ay = y["at"]?.asNumber ?? 0
        if ax != ay { return ax > ay ? x : y }
        let vx = (x["v"] ?? .null).stableString(), vy = (y["v"] ?? .null).stableString()
        return vx >= vy ? x : y
    }

    static func mergeLWWMap(_ a: JSONValue?, _ b: JSONValue?) -> JSONValue {
        let ao = a?.asObject ?? [:], bo = b?.asObject ?? [:]
        var out: [String: JSONValue] = [:]
        for k in Set(ao.keys).union(bo.keys) { out[k] = pickLWW(ao[k], bo[k]) }
        return .object(out)
    }

    private static func idOf(_ item: JSONValue) -> String? {
        if let s = item["id"]?.asString { return s }
        if let n = item["id"]?.asNumber { return JSONValue.number(n).stableString() }
        return nil
    }

    // OR-Set by id: union; dup ids → lexicographically-smaller item. Order: at desc, id asc.
    static func mergeORSet(_ a: JSONValue?, _ b: JSONValue?) -> JSONValue {
        let items = (a?.asArray ?? []) + (b?.asArray ?? [])
        var byId: [String: JSONValue] = [:]
        var order: [String] = []
        for item in items {
            guard let key = idOf(item) else { continue }
            if let prev = byId[key] {
                byId[key] = item.stableString() <= prev.stableString() ? item : prev
            } else {
                byId[key] = item
                order.append(key)
            }
        }
        let merged = order.map { byId[$0]! }.sorted { p, q in
            let ap = p["at"]?.asNumber ?? 0, aq = q["at"]?.asNumber ?? 0
            if ap != aq { return ap > aq }          // at descending
            return (idOf(p) ?? "") < (idOf(q) ?? "") // id ascending
        }
        return .array(merged)
    }

    static func mergeMapOfORSets(_ a: JSONValue?, _ b: JSONValue?) -> JSONValue {
        let ao = a?.asObject ?? [:], bo = b?.asObject ?? [:]
        var out: [String: JSONValue] = [:]
        for k in Set(ao.keys).union(bo.keys) { out[k] = mergeORSet(ao[k], bo[k]) }
        return .object(out)
    }

    static func state(_ a: JSONValue, _ b: JSONValue) -> JSONValue {
        var out: [String: JSONValue] = [:]
        for n in lwwMaps { out[n] = mergeLWWMap(a[n], b[n]) }
        for n in orsetLists { out[n] = mergeORSet(a[n], b[n]) }
        for n in orsetMapLists { out[n] = mergeMapOfORSets(a[n], b[n]) }
        return .object(out)
    }
}
