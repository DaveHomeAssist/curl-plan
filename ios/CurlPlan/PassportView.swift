import SwiftUI

struct PassportView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    telemetry
                    SeasonMap()
                    SectionHeader(title: "Recent stops", action: "All")
                    ForEach(store.recentStops) { stop in
                        NavigationLink(value: Route.stop(stop.id)) {
                            RecentStopTile(stop: stop)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
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
            StatCell(value: "\(store.me.clubs)", label: "CLUBS")
            VRule()
            StatCell(value: "\(store.me.prov)", label: "PROV")
            VRule()
            StatCell(value: "\(store.me.games)", label: "GAMES")
            VRule()
            StatCell(value: "\(store.me.win)%", label: "WIN", accent: true)
        }
        .padding(.vertical, 13)
        .cpCard()
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
                AvatarStack(initials: stop.met.prefix(2).map { _ in "" }, size: 20, plus: stop.plus)
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

                // dashed route (decorative)
                Path { p in
                    let pts: [(Double, Double)] = [(14, 36), (30, 22), (50, 38), (70, 18), (86, 30)]
                    for (i, pt) in pts.enumerated() {
                        let cp = CGPoint(x: w * pt.0 / 100, y: h * pt.1 / 56)
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
                            .overlay(Circle().strokeBorder(.white.opacity(s.here ? 0.85 : 0), lineWidth: 3))
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
            HStack(spacing: 7) {
                Circle().fill(settings.accent).frame(width: 7, height: 7)
                Text("Kamloops · here now").font(.grotesk(11, .semibold)).foregroundStyle(settings.ink)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(settings.card)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            .padding(13)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("12 STOPS · 2,400 KM")
                .font(.mono(10, .medium))
                .tracking(1)
                .foregroundStyle(settings.ink)
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(settings.card.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(12)
        }
    }
}
