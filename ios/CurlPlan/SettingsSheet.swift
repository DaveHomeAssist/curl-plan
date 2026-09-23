import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 14)

            Text("Appearance").font(.serif(24)).foregroundStyle(settings.ink)
            Text("Same season, your circle — tune the ice.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 4)

            settingRow(title: "Theme", sub: "ICE / ARENA") {
                HStack(spacing: 6) {
                    seg("Ice", on: settings.theme == .ice) { settings.theme = .ice }
                    seg("Arena", on: settings.theme == .arena) { settings.theme = .arena }
                }
            }

            settingRow(title: "Accent", sub: "HOUSE COLOUR") {
                HStack(spacing: 8) {
                    ForEach(AppSettings.accents, id: \.key) { a in
                        Button { settings.accentKey = a.key } label: {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(a.color)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(settings.ink, lineWidth: settings.accentKey == a.key ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingRow(title: "Pebble texture", sub: "ICE GRAIN OVERLAY") {
                Toggle("", isOn: Binding(get: { settings.pebble }, set: { settings.pebble = $0 }))
                    .labelsHidden()
                    .tint(settings.accent)
            }

            settingRow(title: "Account", sub: accountMeta) {
                Button {
                    store.signOut()
                    dismiss()
                } label: {
                    Text("Sign out")
                        .font(.grotesk(12, .bold)).foregroundStyle(settings.ink)
                        .padding(.horizontal, 14).padding(.vertical, 6.5)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(452)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    // Canonical team identity: "{Club short} · {Skip}" (see terminology page).
  private var accountMeta: String {
    guard let u = store.currentUser() else { return "SIGNED OUT" }
    let team = clubShort(u.club) + " · " + u.name
    return "DEMO SESSION · " + team
  }
    private func clubShort(_ club: String) -> String {
        club.replacingOccurrences(of: #"\s+(Curling Club|CC)$"#, with: "", options: .regularExpression)
    }

    private func settingRow<Control: View>(title: String, sub: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(settings.line).frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.grotesk(14, .semibold)).foregroundStyle(settings.ink)
                    Text(sub).font(.mono(11, .regular)).tracking(0.5).foregroundStyle(settings.muted)
                }
                Spacer()
                control()
            }
            .padding(.vertical, 13)
        }
    }

    private func seg(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.grotesk(12, .semibold))
                .foregroundStyle(on ? .white : settings.ink)
                .padding(.vertical, 7).padding(.horizontal, 12)
                .background(on ? settings.accent : settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
