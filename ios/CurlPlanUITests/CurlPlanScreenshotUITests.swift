import XCTest

// Opt-in gallery for the screenflow workflow. The runner writes
// /tmp/curlplan-screenshot-config.json after erasing the simulator. Without
// that file the test skips, so an ordinary UI-test run does not capture anything.
final class CurlPlanScreenshotUITests: XCTestCase {
    private let configURL = URL(fileURLWithPath: "/tmp/curlplan-screenshot-config.json")
    private var config: ShotConfig!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 900
        continueAfterFailure = false
    }

    func testCaptureGallery() throws {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw XCTSkip("No screenshot config at \(configURL.path).")
        }
        config = try ShotConfig(url: configURL)
        try FileManager.default.createDirectory(at: config.output, withIntermediateDirectories: true)
        let note = "\(config.deviceName)\n\(config.width)x\(config.height)\n"
        try note.write(to: config.output.appendingPathComponent("device.txt"), atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = []
        applyChrome(appearance: "light")
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        let enter = app.buttons["curlplan.demo.enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 30), "Fresh launch must show the demo gate")
        XCTAssertTrue(app.staticTexts["Your season, your circle"].waitForExistence(timeout: 8))
        if config.captureReview {
            try save(review: "review/light-ice/01-demo-gate.png", store: nil)
        }
        enter.tap()

        try gallery(theme: "light-ice", includeStore: true)
        guard config.captureReview else { return }

        try switchTheme(to: "Arena", appearance: "dark")
        try gallery(theme: "dark-arena", includeStore: false)
        try signOut()
        XCTAssertTrue(app.buttons["curlplan.demo.enter"].waitForExistence(timeout: 15), "Sign out returns to the demo gate")
        try save(review: "review/dark-arena/01-demo-gate.png", store: nil)
    }

    private func gallery(theme: String, includeStore: Bool) throws {
        func review(_ name: String) -> String? {
            config.captureReview ? "review/\(theme)/\(name)" : nil
        }
        func store(_ name: String) -> String? {
            includeStore ? "\(config.storeDir)/\(name)" : nil
        }

        try showPassport()
        try save(review: review("02-passport.png"), store: store("01-passport.png"))

        app.open(URL(string: "curlplan://stop/kelowna")!)
        XCTAssertTrue(app.staticTexts["ICE READ"].waitForExistence(timeout: 12), "Kelowna stop detail")
        try save(review: review("06-stop-detail.png"), store: store("03-stop-detail.png"))
        tap(app.buttons["curlplan.detail.back"], "Back from stop")

        tap(tab("Locker"), "Locker tab")
        XCTAssertTrue(app.staticTexts["Locker Room"].waitForExistence(timeout: 8))
        tap(app.buttons["curlplan.feed.discover"], "Discover")
        let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Took the A-final at Kelowna")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8), "Seeded Kelowna result should be on Discover")
        try save(review: review("03-locker-room.png"), store: store("02-locker-room.png"))

        tap(app.buttons["curlplan.compose.open"], "Compose")
        XCTAssertTrue(app.staticTexts["Share"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Note"].waitForExistence(timeout: 5))
        try save(review: review("09-compose.png"), store: store("07-compose.png"))
        tap(app.buttons["Close"], "Close compose")

        tap(tab("Spiels"), "Spiels tab")
        XCTAssertTrue(app.staticTexts["Brier Patch Open"].waitForExistence(timeout: 8), "Seeded spiel")
        try save(review: review("04-spiels.png"), store: store("05-spiels.png"))

        tap(tab("Roster"), "Roster tab")
        XCTAssertTrue(app.staticTexts["Sam Reid"].waitForExistence(timeout: 8), "Seeded roster")
        try save(review: review("05-roster.png"), store: store("06-roster.png"))

        app.open(URL(string: "curlplan://curler/sam")!)
        XCTAssertTrue(app.buttons["Message"].waitForExistence(timeout: 12), "Sam Reid profile")
        try save(review: review("07-curler-profile.png"), store: store("04-curler-profile.png"))
        guard config.captureReview else { return }

        tap(app.buttons["Message"], "Message")
        XCTAssertTrue(app.buttons["curlplan.thread.close"].waitForExistence(timeout: 8))
        let hello = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Say hello")).firstMatch
        XCTAssertTrue(hello.waitForExistence(timeout: 8), "Empty seeded thread")
        try save(review: review("08-message-thread.png"), store: nil)
        tap(app.buttons["curlplan.thread.close"], "Close message")

        try showPassport()
        tap(app.buttons["Open settings"], "Open settings")
        XCTAssertTrue(app.staticTexts["Appearance"].waitForExistence(timeout: 8))
        try save(review: review("10-settings.png"), store: nil)
        tap(app.buttons["Close settings"], "Close settings")
        XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 8))
    }

    private func showPassport() throws {
        if app.buttons["curlplan.detail.back"].exists {
            app.buttons["curlplan.detail.back"].tap()
        }
        tap(tab("Passport"), "Passport tab")
        XCTAssertTrue(app.buttons["Open settings"].waitForExistence(timeout: 20), "Passport header")
        let hero = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "coast to coast")).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "Passport hero")
    }

    private func switchTheme(to name: String, appearance: String) throws {
        try showPassport()
        tap(app.buttons["Open settings"], "Open settings")
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 8), name)
        app.buttons[name].tap()
        Thread.sleep(forTimeInterval: 0.6)
        tap(app.buttons["Close settings"], "Close settings")
        applyChrome(appearance: appearance)
    }

    private func signOut() throws {
        try showPassport()
        tap(app.buttons["Open settings"], "Open settings")
        tap(app.buttons["Sign out"], "Sign out")
    }

    private func tab(_ title: String) -> XCUIElement {
        let phoneTab = app.tabBars.buttons[title]
        if phoneTab.exists { return phoneTab }
        return app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func tap(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) should exist")
        if !element.isHittable { app.swipeUp() }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func save(review: String?, store: String?) throws {
        let targets = [review, store].compactMap { $0 }
        guard !targets.isEmpty else { return }
        if app.alerts.firstMatch.exists {
            XCTFail("Unexpected alert before \(targets.joined(separator: ", "))")
        }
        XCUIDevice.shared.orientation = .portrait
        applyChrome(appearance: nil)
        Thread.sleep(forTimeInterval: 0.9)
        let temp = config.output.appendingPathComponent("_frame.png")
        // XCUIScreen is the device under test, so a clone cannot steal the frame.
        // simctl is the fallback when that image is not the device's pixel size.
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: temp)
        var size = try pngSize(at: temp)
        print("XCUIScreen \(size.width)x\(size.height)")
        if size.width != config.width || size.height != config.height {
            let simURL = config.output.appendingPathComponent("_sim.png")
            let udid = try captureUDID()
            try xcrun(["simctl", "io", udid, "screenshot", "--type=png", "--mask=black", simURL.path])
            let simSize = try pngSize(at: simURL)
            print("simctl \(simSize.width)x\(simSize.height) \(udid)")
            if simSize.width == config.width && simSize.height == config.height {
                try FileManager.default.removeItem(at: temp)
                try FileManager.default.moveItem(at: simURL, to: temp)
                size = simSize
            } else {
                try? FileManager.default.removeItem(at: simURL)
            }
        }
        for relative in targets {
            let dest = config.output.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: temp, to: dest)
            print("SHOT \(size.width)x\(size.height) \(relative)")
        }
        try? FileManager.default.removeItem(at: temp)
        XCTAssertEqual(size.width, config.width, "\(targets.joined(separator: ", ")) width")
        XCTAssertEqual(size.height, config.height, "\(targets.joined(separator: ", ")) height")
    }

    private func applyChrome(appearance: String?) {
        do {
            let booted = try bootedSimulators().map(\.udid)
            let targets = booted.isEmpty ? [config.udid] : booted
            for udid in targets {
                if let appearance {
                    try xcrun(["simctl", "ui", udid, "appearance", appearance])
                }
                let base = [
                    "simctl", "status_bar", udid, "override",
                    "--time", "9:41",
                    "--dataNetwork", "wifi",
                    "--wifiMode", "active",
                    "--wifiBars", "3",
                    "--cellularMode", "active",
                    "--cellularBars", "4",
                    "--batteryState", "charged",
                    "--batteryLevel", "100",
                ]
                do {
                    try xcrun(base + ["--operatorName", " "])
                } catch {
                    try xcrun(base)
                }
            }
        } catch {
            print("CHROME SKIPPED \(error.localizedDescription)")
        }
    }

    private func captureUDID() throws -> String {
        let booted = try bootedSimulators()
        print("BOOTED \(booted.map { "\($0.name) \($0.udid)" }.joined(separator: " | "))")
        let clones = booted.filter { $0.name.localizedCaseInsensitiveContains("clone") }
        if let clone = clones.first(where: { $0.name.contains(config.deviceName) }) ?? clones.first {
            return clone.udid
        }
        if booted.contains(where: { $0.udid == config.udid }) {
            return config.udid
        }
        if let only = booted.first, booted.count == 1 {
            return only.udid
        }
        XCTFail("No booted simulator for \(config.deviceName)")
        return config.udid
    }

    private func bootedSimulators() throws -> [(name: String, udid: String)] {
        let text = try xcrun(["simctl", "list", "devices", "booted"])
        let pattern = try NSRegularExpression(pattern: #"^\s+(.*?) \(([A-F0-9-]{36})\)"#)
        var rows: [(name: String, udid: String)] = []
        for line in text.split(separator: "\n") {
            let value = String(line)
            let range = NSRange(value.startIndex..., in: value)
            guard let match = pattern.firstMatch(in: value, range: range),
                  let name = Range(match.range(at: 1), in: value),
                  let udid = Range(match.range(at: 2), in: value) else { continue }
            rows.append((String(value[name]), String(value[udid])))
        }
        return rows
    }

    @discardableResult
    private func xcrun(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "curlplan.simctl",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "xcrun \(arguments.joined(separator: " ")) failed: \(text)"]
            )
        }
        return text
    }

    private func pngSize(at url: URL) throws -> (width: Int, height: Int) {
        let data = try Data(contentsOf: url)
        guard data.count >= 24, data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) else {
            throw NSError(domain: "curlplan.simctl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a PNG at \(url.path)"])
        }
        func word(_ start: Int) -> Int {
            data.subdata(in: start..<(start + 4)).reduce(0) { ($0 << 8) | Int($1) }
        }
        return (word(16), word(20))
    }
}

private struct ShotConfig {
    let output: URL
    let udid: String
    let deviceName: String
    let width: Int
    let height: Int
    let captureReview: Bool
    let storeDir: String

    init(url: URL) throws {
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let json = raw as? [String: Any] ?? [:]
        func number(_ key: String) -> Int? {
            if let value = json[key] as? Int { return value }
            if let value = json[key] as? NSNumber { return value.intValue }
            return nil
        }
        func flag(_ key: String) -> Bool? {
            if let value = json[key] as? Bool { return value }
            if let value = json[key] as? NSNumber { return value.boolValue }
            return nil
        }
        guard let output = json["output"] as? String,
              let udid = json["udid"] as? String,
              let deviceName = json["deviceName"] as? String,
              let width = number("width"),
              let height = number("height"),
              let captureReview = flag("captureReview"),
              let storeDir = json["storeDir"] as? String else {
            throw NSError(domain: "curlplan.simctl", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Bad screenshot config \(url.path): \(raw)"
            ])
        }
        self.output = URL(fileURLWithPath: output)
        self.udid = udid
        self.deviceName = deviceName
        self.width = width
        self.height = height
        self.captureReview = captureReview
        self.storeDir = storeDir
    }
}
