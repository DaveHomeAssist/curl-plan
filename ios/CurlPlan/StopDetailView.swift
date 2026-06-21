import SwiftUI

struct StopDetailView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stopID: String

    var body: some View {
        Group {
            if let stop = store.stop(stopID) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        hero(stop)
                        VStack(alignment: .leading, spacing: 14) {
                            iceRead(stop)
                            gamesHere(stop)
                            SectionHeader(title: "People you met here", action: "+ All")
                            people(stop)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 96)
                }
                .background(settings.screen)
                .ignoresSafeArea(edges: .top)
            } else {
                settings.screen
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Hero

    private func hero(_ stop: Stop) -> some View {
        let parts = nameParts(stop.name)
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x2F6B8F), Color(hex: 0x1F2D36)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            PebbleOverlay(opacity: settings.pebbleOpacity, tint: .white.opacity(0.3))
            HouseRing(size: 200).opacity(0.5).offset(x: 130, y: -92)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 2).offset(y: 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 232)
        .clipped()
        .overlay(alignment: .topLeading) {
            CircleBackButton(onDark: true) { dismiss() }
                .padding(.leading, 18)
                .padding(.top, 54)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 5) {
                Text("📍 \(cityLabel(stop))")
                    .font(.mono(10, .medium)).tracking(2)
                    .foregroundStyle(.white.opacity(0.82))
                (Text(parts.0 + " ") + Text(parts.1).italic())
                    .font(.serif(34))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
    }

    // MARK: Ice read

    private func iceRead(_ stop: Stop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Ice read")
            HStack(spacing: 9) {
                iceCell(stop.iceSpeed, "SPEED · \(stop.iceSpeedSec)")
                iceCell(stop.iceCurl, "CURL", suffix: "ft")
                iceCell(stop.iceRec, "YOUR REC", accent: true)
            }
        }
    }

    private func iceCell(_ value: String, _ label: String, suffix: String? = nil, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.serif(22)).foregroundStyle(accent ? settings.accent : settings.ink)
                if let suffix { Text(suffix).font(.system(size: 13)).foregroundStyle(settings.muted) }
            }
            Text(label).font(.mono(9, .medium)).tracking(1).foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11).padding(.horizontal, 12)
        .cpCard(radius: 14)
    }

    // MARK: Games here

    private func gamesHere(_ stop: Stop) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your games here").font(.grotesk(12, .semibold)).foregroundStyle(settings.ink)
                Spacer()
                Text("\(stop.games.count) GP").font(.mono(10, .medium)).foregroundStyle(settings.muted)
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            Rectangle().fill(settings.line).frame(height: 1)

            if stop.games.isEmpty {
                HStack {
                    Text("No games logged here yet").font(.grotesk(13, .medium)).foregroundStyle(settings.muted)
                    Spacer()
                }
                .padding(.vertical, 11).padding(.horizontal, 13)
            } else {
                ForEach(Array(stop.games.enumerated()), id: \.element.id) { idx, g in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(g.res == "W" ? settings.accent : settings.muted)
                            .opacity(g.res == "W" ? 1 : 0.5)
                            .frame(width: 7, height: 7)
                        Text(g.label).font(.grotesk(13, .semibold)).foregroundStyle(settings.ink)
                        Spacer()
                        Text(g.score).font(.serif(16)).foregroundStyle(settings.ink)
                        ResultBadge(res: g.res)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 13)
                    if idx < stop.games.count - 1 { Rectangle().fill(settings.line).frame(height: 1) }
                }
            }
        }
        .cpCard()
    }

    // MARK: People met

    private func people(_ stop: Stop) -> some View {
        VStack(spacing: 12) {
            if stop.met.isEmpty {
                HStack {
                    Text("No connections logged here yet.").font(.mono(11, .medium)).foregroundStyle(settings.muted)
                    Spacer()
                }
            }
            ForEach(stop.met, id: \.self) { id in
                if let c = store.curler(id) {
                    HStack(spacing: 11) {
                        NavigationLink(value: Route.curler(c.id)) {
                            HStack(spacing: 11) {
                                AvatarView(initials: c.initials, size: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                                    Text("\(c.role.uppercased()) · \(c.club.uppercased())")
                                        .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        PillButton(title: c.following ? "Following" : "Follow", filled: !c.following) {
                            store.toggleFollow(c.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func nameParts(_ s: String) -> (String, String) {
        let parts = s.split(separator: " ").map(String.init)
        guard let first = parts.first else { return (s, "") }
        let rest = parts.dropFirst().joined(separator: " ")
        return (first, rest.isEmpty ? "Curling Club" : rest)
    }

    private func cityLabel(_ stop: Stop) -> String {
        let city = stop.club.uppercased().split(separator: " ").first.map(String.init) ?? stop.prov
        return "\(city), \(stop.prov) · \(stop.dates)"
    }
}
