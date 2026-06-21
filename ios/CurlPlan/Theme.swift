import SwiftUI

// MARK: - Color from hex

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Fonts
// The concept uses Instrument Serif / Hanken Grotesk / DM Mono. Those aren't on iOS
// by default, so we map to system designs (serif ≈ New York, mono ≈ SF Mono, sans ≈
// SF). To match the concept exactly, drop the .ttf files into the target and register
// them in Info.plist, then swap these helpers to `.custom(...)`.

extension Font {
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func grotesk(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Theme tokens + persisted appearance prefs

final class AppSettings: ObservableObject {
    enum AppTheme: String { case ice, arena }

    @Published var theme: AppTheme { didSet { persist() } }
    @Published var accentKey: String { didSet { persist() } }
    @Published var pebble: Bool { didSet { persist() } }

    static let accents: [(key: String, color: Color)] = [
        ("House red", Color(hex: 0xC0402C)),
        ("House blue", Color(hex: 0x2F6F93)),
        ("Granite", Color(hex: 0x41505A))
    ]

    let houseRed = Color(hex: 0xC0402C)
    let houseBlue = Color(hex: 0x2F6F93)

    init() {
        let d = UserDefaults.standard
        theme = AppTheme(rawValue: d.string(forKey: "cp.theme") ?? "ice") ?? .ice
        accentKey = d.string(forKey: "cp.accent") ?? "House red"
        pebble = (d.object(forKey: "cp.pebble") as? Bool) ?? true
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(theme.rawValue, forKey: "cp.theme")
        d.set(accentKey, forKey: "cp.accent")
        d.set(pebble, forKey: "cp.pebble")
    }

    // Derived tokens
    var accent: Color { AppSettings.accents.first(where: { $0.key == accentKey })?.color ?? houseRed }
    var isArena: Bool { theme == .arena }
    var ink: Color { isArena ? Color(hex: 0xEEF3F6) : Color(hex: 0x1B2227) }
    var muted: Color { isArena ? Color(hex: 0x8A949B) : Color(hex: 0x6A747B) }
    var line: Color { isArena ? Color.white.opacity(0.09) : Color(hex: 0xDDE4E8) }
    var screen: Color { isArena ? Color(hex: 0x13181B) : Color(hex: 0xECEFF1) }
    var card: Color { isArena ? Color(hex: 0x1B2228) : Color.white }
    var panel: Color { isArena ? Color(hex: 0x222A31) : Color(hex: 0xE6EEF2) }
    var pebbleOpacity: Double { pebble ? 0.6 : 0 }
}
