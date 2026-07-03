import SwiftUI

struct PassportView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showSettings = false
    @State private var showAllStops = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    telemetry
                    if store.stops.isEmpty {
                        EmptyStateView(title: "No stops yet",
                                       message: "Your season map will fill in as you visit rinks or restore an exported season.",
                                       systemImage: "map")
                    } else {
                        SeasonMap()
                    }
                    SectionHeader(title: "Recent stops",
                                  action: store.allActivityStops.isEmpty ? nil : "All",
                                  actionAccessibilityLabel: "Show all stops",
                                  onAction: { showAllStops = true })
                    if store.recentStops.isEmpty {
                        EmptyStateView(title: "No rink activity yet",
                                       message: "Visit a stop from the map or log results to build your Passport history.",
                                       systemImage: "figure.curling")
                    } else {
                        ForEach(store.recentStops) { stop in
                            NavigationLink(value: Route.stop(stop.id)) {
                                RecentStopTile(stop: stop)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("curlplan.recentStop.\(stop.id)")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 96)
                .cpReadableContent()
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: $showAllStops) { AllStopsSheet() }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                HouseRing(size: 22)
                Text("CurlPlan").font(.grotesk(19, .bold)).foregroundStyle(settings.ink)
            }
            Spacer()
            Button { showSettings = true } label: {
                AvatarView(initials: store.me.initials, size: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open settings")
            .accessibilityIdentifier("curlplan.settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .cpReadableContent()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: store.me.season)
            (Text("On the ice, ")
                + Text("coast to coast").foregroundColor(settings.accent).italic())
                .font(.serif(34))
                .foregroundColor(settings.ink)
                .lineSpacing(1)
        }
    }

    private var telemetry: some View {
        HStack(spacing: 0) {
            statCell("\(store.me.clubs)", "CLUBS", identifier: "curlplan.passport.stat.clubs")
            VRule()
            statCell("\(store.me.prov)", "PROV", identifier: "curlplan.passport.stat.provinces")
            VRule()
            statCell("\(store.me.games)", "GAMES", identifier: "curlplan.passport.stat.games")
            VRule()
            statCell("\(store.me.win)%", "WIN", accent: true, identifier: "curlplan.passport.stat.win")
        }
        .padding(.vertical, 13)
        .cpCard()
    }

    private func statCell(_ value: String, _ label: String, accent: Bool = false, identifier: String) -> some View {
        StatCell(value: value, label: label, accent: accent)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(value) \(label)")
            .accessibilityIdentifier(identifier)
    }
}

// MARK: - Recent stop tile

struct RecentStopTile: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let stop: Stop

    var body: some View {
        HStack(spacing: 12) {
            Text(stop.code)
                .font(.mono(12, .semibold))
                .foregroundStyle(settings.accent)
                .frame(width: 42, height: 42)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name).font(.grotesk(15, .bold)).foregroundStyle(settings.ink)
                Text("\(stop.prov) · \(stop.dates)").font(.mono(11, .medium)).foregroundStyle(settings.muted)
            }
            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(stop.record).font(.serif(17)).foregroundStyle(settings.ink)
                AvatarStack(initials: store.initials(for: stop.met), size: 20, plus: store.plusLabel(for: stop.met))
            }
        }
        .padding(12)
        .cpCard()
    }
}

// MARK: - Season map

struct SeasonMap: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                settings.panel

                // grid
                Path { p in
                    for fy in [14.0, 28, 42] {
                        let y = h * fy / 56
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
                    }
                    for fx in [25.0, 50, 75] {
                        let x = w * fx / 100
                        p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
                    }
                }
                .stroke(settings.line, lineWidth: 1)
                .opacity(0.7)

                // route through stops with measured coordinates
                Path { p in
                    let pts = store.stops
                        .filter { $0.latitude != nil && $0.longitude != nil }
                        .map { ($0.x, $0.y) }
                    for (i, pt) in pts.enumerated() {
                        let cp = CGPoint(x: w * pt.0 / 100, y: h * pt.1 / 100)
                        if i == 0 { p.move(to: cp) } else { p.addLine(to: cp) }
                    }
                }
                .stroke(settings.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))
                .opacity(0.75)

                PebbleOverlay(opacity: settings.pebbleOpacity)

                // pins
                ForEach(store.stops) { s in
                    NavigationLink(value: Route.stop(s.id)) {
                        HouseRing(size: s.big ? 21 : 13)
                            .overlay(Circle().strokeBorder(.white.opacity(store.isCurrentStop(s.id) ? 0.85 : 0), lineWidth: 3))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .position(x: w * s.x / 100, y: h * s.y / 100)
                }
            }
        }
        .frame(height: 212)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            let current = store.stops.first { store.isCurrentStop($0.id) }
            HStack(spacing: 7) {
                Circle().fill(settings.accent).frame(width: 7, height: 7)
                Text(current.map { "\($0.club) · active visit" } ?? "Season route")
                    .font(.grotesk(11, .semibold))
                    .foregroundStyle(settings.ink)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(settings.card)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            .padding(13)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(store.seasonSummary.rinks) STOPS · \(store.seasonSummary.distanceLabel) KM")
                .font(.mono(10, .medium))
                .tracking(1)
                .foregroundStyle(settings.ink)
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(settings.card.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(12)
                .accessibilityIdentifier("curlplan.passport.distance")
        }
    }
}

struct AllStopsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    if store.allActivityStops.isEmpty {
                        EmptyStateView(title: "No stops yet",
                                       message: "Visited stops and rink activity will appear here.",
                                       systemImage: "map")
                    } else {
                        ForEach(store.allActivityStops) { stop in
                            NavigationLink(value: Route.stop(stop.id)) {
                                RecentStopTile(stop: stop)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(settings.screen)
            .navigationTitle("All stops")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .stop(let id): StopDetailView(stopID: id)
                case .curler(let id): CurlerProfileView(curlerID: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(settings.accent)
                }
            }
        }
        .presentationBackground(settings.screen)
    }
}
