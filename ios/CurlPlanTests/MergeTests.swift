import XCTest
@testable import CurlPlan

// Runs the SAME data/merge-fixtures.json as the JS reference (scripts/verify-merge.js),
// proving the Swift and JS merge converge identically. Also checks the algebraic laws.
final class MergeTests: XCTestCase {

    struct Case { let name: String; let a: JSONValue; let b: JSONValue; let expected: JSONValue }

    private func loadCases() throws -> [Case] {
        // repo root = up 3 from ios/CurlPlanTests/MergeTests.swift
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("data/merge-fixtures.json")
        let data = try Data(contentsOf: url)
        let doc = try JSONDecoder().decode(JSONValue.self, from: data)
        let cases = doc["cases"]?.asArray ?? []
        return cases.map { c in
            Case(name: c["name"]?.asString ?? "?",
                 a: c["a"] ?? .object([:]), b: c["b"] ?? .object([:]),
                 expected: c["expected"] ?? .object([:]))
        }
    }

    // Fill missing buckets so "absent" compares equal to "present-empty".
    private func fill(_ v: JSONValue) -> JSONValue {
        var o = v.asObject ?? [:]
        for k in Merge.lwwMaps where o[k] == nil { o[k] = .object([:]) }
        for k in Merge.orsetMapLists where o[k] == nil { o[k] = .object([:]) }
        for k in Merge.orsetLists where o[k] == nil { o[k] = .array([]) }
        if o["tombstones"] == nil { o["tombstones"] = .object([:]) }
        return .object(o)
    }
    private func canon(_ v: JSONValue) -> String { fill(v).stableString() }

    func testFixturesAndLaws() throws {
        let cases = try loadCases()
        XCTAssertGreaterThan(cases.count, 0, "no fixtures loaded")
        for c in cases {
            let ab = Merge.state(c.a, c.b)
            XCTAssertEqual(canon(ab), canon(c.expected), "\(c.name): merge(a,b) != expected")
            XCTAssertEqual(canon(Merge.state(c.b, c.a)), canon(ab), "\(c.name): not commutative")
            XCTAssertEqual(canon(Merge.state(ab, ab)), canon(ab), "\(c.name): not idempotent")
        }
    }

    func testAssociativityAcrossFixtures() throws {
        let states = try loadCases().flatMap { [$0.a, $0.b] }.filter { !($0.asObject?.isEmpty ?? true) }
        var i = 0
        while i + 2 < states.count {
            let (a, b, c) = (states[i], states[i + 1], states[i + 2])
            XCTAssertEqual(canon(Merge.state(Merge.state(a, b), c)),
                           canon(Merge.state(a, Merge.state(b, c))),
                           "associativity failed at \(i)")
            i += 3
        }
    }
}
