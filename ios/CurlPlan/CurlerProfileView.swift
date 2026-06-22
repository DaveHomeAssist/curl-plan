import SwiftUI

struct CurlerProfileView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let curlerID: String

    var body: some View {
        Group {
            if let c = store.curler(curlerID) {
                VStack(spacing: 0) {
                    HStack {
                        CircleBackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            identity(c)
                            actions(c)
                            stats(c)
                            sharedRinks(c)
                            recentForm(c)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 96)
                    }
                }
                .background(settings.screen)
            } else {
                settings.screen
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func identity(_ c: Curler) -> some View {
        VStack(spacing: 9) {
            ZStack {
                Circle().fill(settings.screen)
                Circle().strokeBorder(settings.houseRed, lineWidth: 4)
                Circle().strokeBorder(settings.houseBlue, lineWidth: 4).padding(7)
                AvatarView(initials: c.initials, size: 78)
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 5) {
                Text(c.name).font(.serif(30)).foregroundStyle(settings.ink)
                Text("\(c.role.uppercased()) · \(c.club.uppercased()) · \(c.prov)")
                    .font(.mono(11, .medium)).tracking(1).foregroundStyle(settings.muted)
            }

            HStack(spacing: 7) {
                Circle().fill(settings.accent).frame(width: 6, height: 6)
                Text("You met at \(c.metAt)").font(.grotesk(11, .semibold)).foregroundStyle(settings.accent)
            }
            .padding(.vertical, 5).padding(.horizontal, 12)
            .background(settings.panel)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private func actions(_ c: Curler) -> some View {
        HStack(spacing: 10) {
            Button { store.toggleFollow(c.id) } label: {
                Text(c.following ? "Following" : "+ Follow")
                    .font(.grotesk(14, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(settings.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            ShareLink(item: "\(c.name) — \(c.role), \(c.club) (\(c.prov)). Met at \(c.metAt). Record \(c.record), \(c.win) wins.") {
                Text("Share")
                    .font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 11.5)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.ink, lineWidth: 1.5))
            }
        }
    }

    private func stats(_ c: Curler) -> some View {
        HStack(spacing: 0) {
            statCell(c.record, "RECORD")
            VRule()
            statCell(c.win, "WIN", accent: true)
            VRule()
            statCell("\(c.rinks)", "RINKS")
            VRule()
            statCell("\(c.mutual)", "MUTUAL")
        }
        .padding(.vertical, 14)
        .cpCard()
    }

    private func statCell(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.serif(24)).foregroundStyle(accent ? settings.accent : settings.ink)
            Text(label).font(.mono(9, .medium)).tracking(1).foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func sharedRinks(_ c: Curler) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Rinks you've both played")
            HStack(spacing: 8) {
                ForEach(Array(c.sharedRinks.enumerated()), id: \.offset) { _, label in
                    let isMore = label.contains("more")
                    HStack(spacing: 6) {
                        if !isMore { HouseRing(size: 12) }
                        Text(label).font(.grotesk(12, .semibold))
                            .foregroundStyle(isMore ? settings.muted : settings.ink)
                    }
                    .padding(.vertical, 6)
                    .padding(.leading, isMore ? 11 : 7)
                    .padding(.trailing, 11)
                    .overlay(Capsule().strokeBorder(settings.line, lineWidth: 1))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func recentForm(_ c: Curler) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Recent form")
            VStack(spacing: 0) {
                ForEach(Array(c.form.enumerated()), id: \.element.id) { idx, g in
                    HStack(spacing: 10) {
                        Text(g.label).font(.grotesk(13, .semibold)).foregroundStyle(settings.ink)
                        Spacer()
                        Text(g.score).font(.serif(16)).foregroundStyle(settings.ink)
                        ResultBadge(res: g.res)
                    }
                    .padding(.vertical, 11).padding(.horizontal, 13)
                    if idx < c.form.count - 1 { Rectangle().fill(settings.line).frame(height: 1) }
                }
            }
            .cpCard(radius: 14)
        }
    }
}
