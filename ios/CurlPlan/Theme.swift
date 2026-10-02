import SwiftUI
import UIKit

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

// Surface and text values shared by the SwiftUI tokens and the UIKit tab bar.
enum Palette {
    static let iceCard: UInt = 0xFFFFFF
    static let arenaCard: UInt = 0x1B2228
    static let iceMuted: UInt = 0x465159
    static let arenaMuted: UInt = 0xB3BCC2
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    /// Ice renders in light mode and Arena in dark mode (preferredColorScheme).
    static func themed(ice: UInt, arena: UInt) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: arena) : UIColor(hex: ice) }
    }
}

// MARK: - Tab bar chrome
// The tab bar is a solid card surface with muted unselected items (about 8:1 on
// card in both themes). The system default was a translucent material with gray
// items near 2.6:1, and rows partly beneath the bar failed contrast audits.
// SwiftUI ignores toolbarBackground(_:for: .tabBar) on a TabView and has no
// unselected-item color, so the bar is styled through UIKit appearance.

enum TabBarStyle {
    static func appearance() -> UITabBarAppearance {
        let muted = UIColor.themed(ice: Palette.iceMuted, arena: Palette.arenaMuted)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.themed(ice: Palette.iceCard, arena: Palette.arenaCard)
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = muted
            layout.normal.titleTextAttributes = [.foregroundColor: muted]
        }
        return appearance
    }

    static func apply() {
        let bar = UITabBar.appearance()
        bar.standardAppearance = appearance()
        bar.scrollEdgeAppearance = appearance()
    }
}

// MARK: - Fonts
// The concept uses Instrument Serif / Hanken Grotesk / DM Mono. Those aren't on iOS
// by default, so we map to system designs (serif ≈ New York, mono ≈ SF Mono, sans ≈
// SF). To match the concept exactly, drop the .ttf files into the target and register
// them in Info.plist, then swap these helpers to `.custom(...)`.

extension Font {
    private static func scaledStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11: return .caption2
        case ..<13: return .caption
        case ..<15: return .footnote
        case ..<17: return .subheadline
        case ..<20: return .body
        case ..<23: return .title3
        case ..<27: return .title2
        case ..<33: return .title
        default: return .largeTitle
        }
    }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(scaledStyle(for: size), design: .serif).weight(weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(scaledStyle(for: size), design: .monospaced).weight(weight)
    }
    static func grotesk(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(scaledStyle(for: size)).weight(weight)
    }
}

// MARK: - Theme tokens + persisted appearance prefs

final class AppSettings: ObservableObject {
    enum AppTheme: String { case ice, arena }

    @Published var theme: AppTheme { didSet { persist() } }
    @Published var accentKey: String { didSet { persist() } }
    @Published var pebble: Bool { didSet { persist() } }

    static let accents: [(key: String, color: Color)] = [
        ("House red", Color(hex: 0x9C2F20)),
        ("House blue", Color(hex: 0x2F6F93)),
        ("Granite", Color(hex: 0x41505A))
    ]

    let houseRed = Color(hex: 0xB73726)
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
    var accent: Color {
        if isArena {
            switch accentKey {
            case "House blue": return Color(hex: 0x78C8F0)
            case "Granite": return Color(hex: 0xBCC8CE)
            default: return Color(hex: 0xFF826E)
            }
        }
        return AppSettings.accents.first(where: { $0.key == accentKey })?.color ?? Color(hex: 0x9C2F20)
    }
    // Text/icons on a filled accent surface need the opposite luminance in Arena.
    var onAccent: Color { isArena ? Color(hex: 0x13181B) : .white }
    var isArena: Bool { theme == .arena }
    var ink: Color { isArena ? Color(hex: 0xEEF3F6) : Color(hex: 0x1B2227) }
    var muted: Color { isArena ? Color(hex: Palette.arenaMuted) : Color(hex: Palette.iceMuted) }
    var line: Color { isArena ? Color.white.opacity(0.09) : Color(hex: 0xDDE4E8) }
    var screen: Color { isArena ? Color(hex: 0x13181B) : Color(hex: 0xECEFF1) }
    var card: Color { isArena ? Color(hex: Palette.arenaCard) : Color(hex: Palette.iceCard) }
    var panel: Color { isArena ? Color(hex: 0x222A31) : Color(hex: 0xE6EEF2) }
    var pebbleOpacity: Double { pebble ? 0.6 : 0 }
}
