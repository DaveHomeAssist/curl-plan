import XCTest

// Opt-in gallery for the screenflow workflow. The runner writes
// /tmp/curlplan-screenshot-config.json after erasing the simulator. Without
// that file the test skips, so an ordinary UI-test run does not capture anything.
final class CurlPlanScreenshotUITests: XCTestCase {
    private let configURL = URL(fileURLWithPath: "/tmp/curlplan-screenshot-config.json")
    private var config: ShotConfig!
    private var app: XCUIApplication!
    private var pendingAppearance: String?

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
        Thread.sleep(forTimeInterval: 0.8)
        let temp = try requestHostShot()
        let size = try pngSize(at: temp)
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

    /// Ask the Mac-side watcher (scripts/capture-ios-frame.py) for a framebuffer PNG.
    /// The test bundle is compiled against the iOS SDK, so it cannot start simctl itself.
    private func requestHostShot() throws -> URL {
        let id = UUID().uuidString
        let reply = config.output.appendingPathComponent("_shots/\(id).png")
        let requests = config.output.appendingPathComponent("_requests")
        try FileManager.default.createDirectory(at: requests, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: reply.deletingLastPathComponent(), withIntermediateDirectories: true)
        var payload: [String: String] = ["reply": reply.path]
        if let appearance = pendingAppearance {
            payload["appearance"] = appearance
            pendingAppearance = nil
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        let partial = requests.appendingPathComponent(id + ".partial")
        try data.write(to: partial)
        try FileManager.default.moveItem(at: partial, to: requests.appendingPathComponent(id + ".json"))
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: reply.path) {
                let size = try pngSize(at: reply)
                if size.width > 0 { return reply }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw NSError(domain: "curlplan.simctl", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Host did not capture \(reply.path)"
        ])
    }

    private func applyChrome(appearance: String?) {
        if let appearance { pendingAppearance = appearance }
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
