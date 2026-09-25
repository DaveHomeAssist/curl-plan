import SwiftUI

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
    private let baseSize: CGFloat
    @ScaledMetric(relativeTo: .caption2) private var scaledSize: CGFloat = 0

    init(initials: String, size: CGFloat = 34) {
        self.initials = initials
        baseSize = size
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .caption2)
    }

    var body: some View {
        Text(initials)
            .font(.grotesk(baseSize * 0.36, .bold))
            .foregroundStyle(Color(hex: 0xEEF3F6))
            .frame(width: scaledSize, height: scaledSize)
            .background(
                LinearGradient(colors: [Color(hex: 0x3A444B), Color(hex: 0x222A30)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

// Compact avatar stack (the "met people" cluster). Keep initials unobscured so
// every visible avatar remains legible at larger text sizes.
struct AvatarStack: View {
    @EnvironmentObject var settings: AppSettings
    let initials: [String]
    private let accessibilityNames: [String]
    private let baseSize: CGFloat
    private let plus: String?
    @ScaledMetric(relativeTo: .caption2) private var scaledSize: CGFloat = 0

    init(initials: [String], accessibilityNames: [String]? = nil,
         size: CGFloat = 28, plus: String? = nil) {
        self.initials = initials
        self.accessibilityNames = accessibilityNames ?? initials
        baseSize = size
        self.plus = plus
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .caption2)
    }

    var body: some View {
        HStack(spacing: max(2, scaledSize * 0.08)) {
            ForEach(Array(initials.enumerated()), id: \.offset) { _, ini in
                AvatarStackGlyph(text: ini, baseSize: baseSize, scaledSize: scaledSize)
                    .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
            }
            if let plus {
                AvatarStackGlyph(text: plus, baseSize: baseSize, scaledSize: scaledSize, accent: true)
                    .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stackLabel)
    }

    private var stackLabel: String {
        let people = accessibilityNames.joined(separator: ", ")
        guard let plus else { return "People: \(people)" }
        return "People: \(people), \(plus.dropFirst()) more"
    }
}

// Initials are redundant visual shorthand. The parent stack supplies the full
// VoiceOver label, while this canvas keeps the glyph and its circle scaling as
// one unit instead of exposing constrained individual text elements.
private struct AvatarStackGlyph: View {
    @EnvironmentObject var settings: AppSettings
    let text: String
    let baseSize: CGFloat
    let scaledSize: CGFloat
    var accent = false

    var body: some View {
        ZStack {
            if accent {
                Circle().fill(settings.accent)
            } else {
                Circle().fill(
                    LinearGradient(colors: [Color(hex: 0x3A444B), Color(hex: 0x222A30)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
            Canvas { context, size in
                let glyph = context.resolve(
                    Text(text)
                        .font(.grotesk(baseSize * (accent ? 0.34 : 0.36), .bold))
                        .foregroundColor(.white)
                )
                context.draw(glyph,
                             at: CGPoint(x: size.width / 2, y: size.height / 2),
                             anchor: .center)
            }
        }
        .frame(width: scaledSize, height: scaledSize)
        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1.5))
        .accessibilityHidden(true)
    }
}

// MARK: - Stat cell (telemetry strips on Passport + profiles)

struct StatCell: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                .font(.mono(11, .semibold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1.2)
                .foregroundStyle(settings.muted)
                .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.mono(12, .semibold))
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0.5 : 2)
            .foregroundStyle(settings.muted)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SectionHeader: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    var action: String? = nil
    var onTap: (() -> Void)? = nil     // when set, the action label becomes a real control

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.mono(12, .semibold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
                .foregroundStyle(settings.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let action {
                if let onTap {
                    Button(action: onTap) {
                        Text(action).font(.grotesk(12, .semibold)).foregroundStyle(settings.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(action).font(.grotesk(12, .semibold)).foregroundStyle(settings.accent)
                }
            }
        }
    }
}

// Win/Loss letter in accent (W) or muted (L).
struct ResultBadge: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let res: String
    var body: some View {
        Text(res)
            .font(.mono(11, .bold))
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
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
                .fixedSize(horizontal: true, vertical: true)
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
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    let on = selection == opt
                    Button { selection = opt } label: {
                        Text(opt)
                            .font(.grotesk(12, .semibold))
                            .foregroundStyle(on ? .white : settings.ink)
                            .padding(.vertical, 8).padding(.horizontal, 13)
                            .background(on ? settings.accent : settings.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
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
                VStack(alignment: .leading, spacing: 14) { content() }
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel").font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Button(action: onSave) {
                    Text("Save").font(.grotesk(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(canSave ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
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

// Read-only star rating (filled accent + empty line), matching the web starsRow().
struct StarsRow: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let count: Int
    var size: CGFloat = 13
    var body: some View {
        let n = max(0, min(5, count))
        return HStack(spacing: 0) {
            Text(String(repeating: "★", count: n)).foregroundColor(settings.accent)
            Text(String(repeating: "★", count: 5 - n)).foregroundColor(settings.muted)
        }
            .font(.grotesk(size))
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
            .fixedSize(horizontal: true, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(n) out of 5 stars")
            .accessibilityRespondsToUserInteraction(false)
    }
}

// Interactive 5-star picker for review/rating inputs.
struct StarPicker: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var rating: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Button { rating = i } label: {
                    Text("★")
                        .font(.system(size: 26))
                        .foregroundStyle(i <= rating ? settings.accent : settings.line)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Labelled multi-line text field (compose bodies, notes, messages).
struct CPTextArea: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 74

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.grotesk(15)).foregroundStyle(settings.muted)
                        .padding(.vertical, 11).padding(.horizontal, 13)
                }
                TextField("", text: $text, axis: .vertical)
                    .font(.grotesk(15)).foregroundStyle(settings.ink)
                    .tint(settings.accent)
                    .padding(.vertical, 11).padding(.horizontal, 13)
            }
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(settings.line, lineWidth: 1))
        }
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
        .accessibilityLabel("Back")
        .accessibilityIdentifier("curlplan.detail.back")
    }
}
