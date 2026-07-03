import SwiftUI

enum CPLayout {
    static let readableWidth: CGFloat = 900
    static let tabBarWidth: CGFloat = 760
}

extension View {
    func cpReadableContent(maxWidth: CGFloat = CPLayout.readableWidth,
                           alignment: Alignment = .center) -> some View {
        frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - House ring (the signature element)
// Concentric curling-house rings: white centre button, red ring, white, blue ring,
// white rim — matching the concept's radial gradient.

struct HouseRing: View {
    var size: CGFloat = 22
    private let red = Color(hex: 0xC0402C)
    private let blue = Color(hex: 0x2F6F93)

    var body: some View {
        ZStack {
            Circle().fill(.white)
            Circle().fill(blue).scaleEffect(0.86)
            Circle().fill(.white).scaleEffect(0.61)
            Circle().fill(red).scaleEffect(0.35)
            Circle().fill(.white).scaleEffect(0.09)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 34

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(Color(hex: 0xEEF3F6))
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Color(hex: 0x3A444B), Color(hex: 0x222A30)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1.5))
    }
}

// Overlapping avatar stack (the "met people" cluster).
struct AvatarStack: View {
    @EnvironmentObject var settings: AppSettings
    let initials: [String]
    var size: CGFloat = 28
    var plus: String? = nil

    var body: some View {
        Group {
            if initials.isEmpty && plus == nil {
                AvatarView(initials: "?", size: size)
                    .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
                    .opacity(0.55)
            } else {
                HStack(spacing: -size * 0.32) {
                    ForEach(Array(initials.enumerated()), id: \.offset) { _, ini in
                        AvatarView(initials: ini.isEmpty ? "?" : ini, size: size)
                            .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
                    }
                    if let plus {
                        Text(plus)
                            .font(.system(size: size * 0.34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: size, height: size)
                            .background(settings.accent)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
                    }
                }
            }
        }
    }
}

// MARK: - Stat cell (telemetry strips on Passport + profiles)

struct StatCell: View {
    @EnvironmentObject var settings: AppSettings
    let value: String
    let label: String
    var accent: Bool = false
    var size: CGFloat = 26

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.serif(size))
                .foregroundStyle(accent ? settings.accent : settings.ink)
            Text(label)
                .font(.mono(9, .medium))
                .tracking(1.2)
                .foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pebble texture overlay

struct PebbleOverlay: View {
    var opacity: Double
    var tint: Color = Color(hex: 0x6E828C)

    var body: some View {
        Canvas { ctx, size in
            // one accumulated path + one fill, not a draw call per dot
            var dots = Path()
            let step: CGFloat = 9
            var y: CGFloat = 2
            while y < size.height {
                var x: CGFloat = 2
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x, y: y, width: 1.6, height: 1.6))
                    x += step
                }
                y += step
            }
            ctx.fill(dots, with: .color(tint))
        }
        .opacity(opacity * 0.55)
        .allowsHitTesting(false)
    }
}

// MARK: - Card surface

struct CardStyle: ViewModifier {
    @EnvironmentObject var settings: AppSettings
    var radius: CGFloat = 16
    var accentBorder: Bool = false

    func body(content: Content) -> some View {
        content
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(accentBorder ? settings.accent : settings.line,
                                  lineWidth: accentBorder ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(settings.isArena ? 0.35 : 0.10), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func cpCard(radius: CGFloat = 16, accentBorder: Bool = false) -> some View {
        modifier(CardStyle(radius: radius, accentBorder: accentBorder))
    }
}

// MARK: - Small reusable bits

struct Eyebrow: View {
    @EnvironmentObject var settings: AppSettings
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.mono(11, .medium))
            .tracking(2)
            .foregroundStyle(settings.muted)
    }
}

struct SectionHeader: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    var action: String? = nil
    var actionAccessibilityLabel: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.mono(11, .medium))
                .tracking(2)
                .foregroundStyle(settings.muted)
            Spacer()
            if let action {
                if let onAction {
                    Button(action: onAction) {
                        Text(action)
                            .font(.grotesk(12, .semibold))
                            .foregroundStyle(settings.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(actionAccessibilityLabel ?? action)
                } else {
                    Text(action)
                        .font(.grotesk(12, .semibold))
                        .foregroundStyle(settings.accent)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    let message: String
    var systemImage: String = "house"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(settings.accent)
            Text(title)
                .font(.grotesk(15, .bold))
                .foregroundStyle(settings.ink)
            Text(message)
                .font(.grotesk(13))
                .foregroundStyle(settings.muted)
                .lineSpacing(2)
            if let actionTitle, let action {
                PillButton(title: actionTitle, filled: true, action: action)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .cpCard(radius: 14)
    }
}

// Win/Loss letter in accent (W) or muted (L).
struct ResultBadge: View {
    @EnvironmentObject var settings: AppSettings
    let res: String
    var body: some View {
        Text(res)
            .font(.mono(9, .bold))
            .tracking(1)
            .foregroundStyle(res == "W" ? settings.accent : settings.muted)
    }
}

// Pill-style action button.
struct PillButton: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    var filled: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.grotesk(12, .bold))
                .foregroundStyle(filled ? .white : settings.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, filled ? 8 : 6.5)
                .background(filled ? settings.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(settings.ink, lineWidth: filled ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// Thin vertical divider used inside stat strips.
struct VRule: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View { Rectangle().fill(settings.line).frame(width: 1) }
}

// MARK: - Create-sheet building blocks

// Labelled text field styled to the panel/line tokens.
struct CPField: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    private var fieldID: String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        let lower = label.lowercased()
        let mapped = lower.map { allowed.contains($0) ? String($0) : "-" }.joined()
        return mapped.split(separator: "-").joined(separator: "-")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
            TextField(placeholder, text: $text)
                .font(.grotesk(15)).foregroundStyle(settings.ink)
                .tint(settings.accent)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.vertical, 11).padding(.horizontal, 13)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(settings.line, lineWidth: 1))
                .accessibilityIdentifier("curlplan.field.\(fieldID)")
        }
    }
}

// Single-select chip row (status / role pickers).
struct CPChips: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { opt in
                        let on = selection == opt
                        Button { selection = opt } label: {
                            Text(opt)
                                .font(.grotesk(12, .semibold))
                                .foregroundStyle(on ? .white : settings.ink)
                                .lineLimit(1)
                                .padding(.vertical, 8).padding(.horizontal, 13)
                                .background(on ? settings.accent : settings.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// Shared scaffold for the create sheets: drag handle, title, fields, Cancel/Save bar.
struct CreateScaffold<Content: View>: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    let subtitle: String
    let canSave: Bool
    var validationMessage: String? = nil
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 14)

            Text(title).font(.serif(24)).foregroundStyle(settings.ink)
            Text(subtitle).font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                    if let validationMessage, !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.grotesk(12, .semibold))
                            .foregroundStyle(settings.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel").font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("curlplan.sheet.cancel")

                Button(action: onSave) {
                    Text("Save").font(.grotesk(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(canSave ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityIdentifier("curlplan.sheet.save")
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }
}

// A circular glass back button for hero / detail screens.
struct CircleBackButton: View {
    @EnvironmentObject var settings: AppSettings
    var onDark: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(onDark ? .white : settings.ink)
                .frame(width: 36, height: 36)
                .background(onDark ? Color.white.opacity(0.16) : settings.card)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(onDark ? Color.clear : settings.line, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}
