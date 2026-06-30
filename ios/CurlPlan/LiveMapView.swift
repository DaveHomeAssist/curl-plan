import SwiftUI
import MapKit

struct LiveMapView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedStopID: String?
    @State private var filter: LiveStopFilter = .all
    @State private var routeMode: LiveRouteMode = .order
    @State private var query = ""
    @State private var cameraRegion = LiveMapStop.defaultRegion
    @State private var cameraPosition = MapCameraPosition.region(LiveMapStop.defaultRegion)

    private var stops: [LiveMapStop] { store.liveMapStops }

    private var selectedStop: LiveMapStop? {
        selectedStopID.flatMap { id in stops.first { $0.id == id } }
    }

    private var currentStop: LiveMapStop? {
        stops.first(where: \.current) ?? stops.first
    }

    private var visibleStopIDs: Set<String> {
        Set(stops.filter(matchesCurrentControls).map(\.id))
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        stops.map(\.coordinate)
    }

    private var compact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            settings.screen.ignoresSafeArea()

            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
                routeContent

                ForEach(stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate, anchor: .center) {
                        Button {
                            select(stop)
                        } label: {
                            LiveMapPin(stop: stop,
                                       selected: selectedStopID == stop.id,
                                       dimmed: !visibleStopIDs.contains(stop.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(for: stop))
                    }
                }
            }
            .mapControls { }
            .onMapCameraChange { context in
                cameraRegion = context.region
            }
            .ignoresSafeArea(edges: .top)

            LinearGradient(colors: [Color.black.opacity(settings.isArena ? 0.38 : 0.18), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
                .frame(height: 180)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            topControls
            rightControls
            bottomControls
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @MapContentBuilder
    private var routeContent: some MapContent {
        switch routeMode {
        case .order:
            if routeCoordinates.count > 1 {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(settings.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [1, 9]))
            } else {
                EmptyMapContent()
            }
        case .home:
            if let home = stops.first(where: \.home) {
                ForEach(stops.filter { !$0.home }) { stop in
                    MapPolyline(coordinates: [home.coordinate, stop.coordinate])
                        .stroke(settings.accent, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round, dash: [1, 9]))
                }
            } else {
                EmptyMapContent()
            }
        case .off:
            EmptyMapContent()
        }
    }

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                HouseRing(size: 18)
                Text("CurlPlan")
                    .font(.grotesk(14, .bold))
                    .foregroundStyle(settings.ink)
                Text("Passport")
                    .font(.mono(10, .medium))
                    .tracking(1.6)
                    .foregroundStyle(settings.muted)
                    .textCase(.uppercase)
                    .padding(.leading, 9)
                    .overlay(Rectangle().fill(settings.line).frame(width: 1), alignment: .leading)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 9)
            .accessibilityElement(children: .combine)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settings.muted)
                TextField("Search rinks & cities", text: $query)
                    .font(.grotesk(14, .medium))
                    .foregroundStyle(settings.ink)
                    .tint(settings.accent)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(settings.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: 520)
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 9)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(LiveStopFilter.allCases) { item in
                        Button {
                            filter = item
                            if let selectedStop, !matchesCurrentControls(selectedStop) {
                                selectedStopID = nil
                            }
                        } label: {
                            Text(item.title)
                                .font(.grotesk(12, .semibold))
                                .foregroundStyle(filter == item ? .white : settings.ink)
                                .lineLimit(1)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 15)
                                .background(filter == item ? settings.accent : settings.card)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Filter \(item.title)")
                    }
                }
                .padding(.trailing, 18)
            }
            .frame(maxWidth: 560)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var rightControls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                mapControlButton("plus", label: "Zoom in") { zoom(0.55) }
                Rectangle().fill(settings.line).frame(height: 1)
                mapControlButton("minus", label: "Zoom out") { zoom(1.65) }
            }
            .frame(width: 46)
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 9)

            mapControlButton("location", label: "Locate current stop") {
                if let currentStop {
                    focus(on: currentStop, latitudeDelta: 3.4, longitudeDelta: 5.2)
                }
            }
            .frame(width: 46, height: 46)
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 9)
        }
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private var bottomControls: some View {
        VStack {
            Spacer()

            if compact {
                VStack(alignment: .trailing, spacing: 10) {
                    routeToggle
                    sheetContent
                }
            } else {
                HStack(alignment: .bottom, spacing: 16) {
                    sheetContent
                    Spacer(minLength: 18)
                    routeToggle
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, compact ? 92 : 88)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let selectedStop {
            selectedStopSheet(selectedStop)
        } else {
            summarySheet
        }
    }

    private var summarySheet: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your season map")
                        .font(.serif(25))
                        .foregroundStyle(settings.ink)
                    Text("2025–26 · IN PROGRESS")
                        .font(.mono(10, .medium))
                        .tracking(1)
                        .foregroundStyle(settings.muted)
                }
                Spacer()
                Button {
                    routeMode = .order
                    selectedStopID = nil
                    resetMap()
                } label: {
                    Text("Timeline ›")
                        .font(.grotesk(12, .semibold))
                        .foregroundStyle(settings.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show travel timeline")
            }

            HStack(spacing: 0) {
                seasonStat("\(store.seasonSummary.rinks)", "RINKS")
                VRule().frame(height: 48)
                seasonStat("\(store.seasonSummary.provinces)", "PROV")
                VRule().frame(height: 48)
                seasonStat(store.seasonSummary.distanceLabel, "KM")
                VRule().frame(height: 48)
                seasonStat("\(store.seasonSummary.met)", "MET", accent: true)
            }
            .padding(.vertical, 13)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(stops.isEmpty ? "Start a season or import data to build your map" : "Tap any house pin to pull up the stop · drag to pan the country")
                .font(.grotesk(11, .medium))
                .foregroundStyle(settings.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: compact ? .infinity : 360, alignment: .leading)
        .background(settings.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 32, x: 0, y: 18)
    }

    private func selectedStopSheet(_ stop: LiveMapStop) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Text(stop.code)
                    .font(.mono(13, .semibold))
                    .tracking(0.4)
                    .foregroundStyle(settings.accent)
                    .frame(width: 50, height: 50)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(stop.name)
                        .font(.serif(25))
                        .foregroundStyle(settings.ink)
                        .lineLimit(2)
                    Text(stop.meta)
                        .font(.mono(10, .medium))
                        .tracking(0.8)
                        .foregroundStyle(settings.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(stop.record)
                    .font(.serif(22))
                    .foregroundStyle(settings.accent)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                stopMetric(stop.speed, "SPEED")
                stopMetric(stop.curl, "CURL")
                stopMetric(stop.games, "GAMES")
                stopMetric(stop.met, "MET")
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("People you met here")
                    .font(.mono(10, .medium))
                    .tracking(1.4)
                    .foregroundStyle(settings.muted)
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    HStack(spacing: -10) {
                        ForEach(stop.people, id: \.self) { person in
                            AvatarView(initials: person, size: 36)
                                .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
                        }
                    }

                    Text(stop.peopleLabel)
                        .font(.grotesk(13, .medium))
                        .foregroundStyle(settings.muted)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 10) {
                NavigationLink(value: Route.stop(stop.id)) {
                    Text("Open stop")
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(settings.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: settings.accent.opacity(0.28), radius: 16, y: 8)
                }
                .buttonStyle(.plain)

                Button {
                    store.markStopVisited(stop.id)
                } label: {
                    Image(systemName: stop.current ? "checkmark" : "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(stop.current ? settings.accent : settings.ink)
                        .frame(width: 50, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(stop.current ? settings.accent : settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(stop.current ? "Stop already has an active visit" : "Start stop visit")

                Button {
                    selectedStopID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(settings.ink)
                        .frame(width: 50, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear selected stop")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: compact ? .infinity : 372, alignment: .leading)
        .background(settings.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.38), radius: 34, x: 0, y: 18)
    }

    private var routeToggle: some View {
        Button {
            routeMode = routeMode.next
        } label: {
            HStack(spacing: 9) {
                RouteGlyph()
                    .stroke(settings.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
                    .frame(width: 24, height: 15)
                    .overlay(alignment: .topLeading) {
                        Circle().fill(settings.accent).frame(width: 5, height: 5)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(settings.accent).frame(width: 5, height: 5)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUTE")
                        .font(.mono(8, .medium))
                        .tracking(1.2)
                        .foregroundStyle(settings.muted)
                    Text(routeMode.title)
                        .font(.grotesk(12, .bold))
                        .foregroundStyle(settings.ink)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background(settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 20, x: 0, y: 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Route mode \(routeMode.title)")
    }

    private func mapControlButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(systemName == "location" ? settings.accent : settings.ink)
                .contentShape(Rectangle())
        }
        .frame(width: 46, height: 46)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func seasonStat(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.serif(23))
                .foregroundStyle(accent ? settings.accent : settings.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.mono(9, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func stopMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.serif(18))
                .foregroundStyle(settings.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.mono(8, .medium))
                .tracking(0.8)
                .foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .background(settings.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func select(_ stop: LiveMapStop) {
        guard visibleStopIDs.contains(stop.id) else { return }
        selectedStopID = stop.id
        focus(on: stop, latitudeDelta: 2.9, longitudeDelta: 4.5)
    }

    private func focus(on stop: LiveMapStop, latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees) {
        cameraRegion = MKCoordinateRegion(center: stop.coordinate,
                                          span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(cameraRegion)
        }
    }

    private func resetMap() {
        cameraRegion = LiveMapStop.defaultRegion
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(cameraRegion)
        }
    }

    private func zoom(_ factor: CLLocationDegrees) {
        let lat = min(max(cameraRegion.span.latitudeDelta * factor, 0.6), 18)
        let lon = min(max(cameraRegion.span.longitudeDelta * factor, 0.8), 34)
        cameraRegion = MKCoordinateRegion(center: cameraRegion.center,
                                          span: MKCoordinateSpan(latitudeDelta: lat, longitudeDelta: lon))
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(cameraRegion)
        }
    }

    private func matchesCurrentControls(_ stop: LiveMapStop) -> Bool {
        guard filter.includes(stop) else { return false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return stop.name.localizedCaseInsensitiveContains(trimmed)
            || stop.city.localizedCaseInsensitiveContains(trimmed)
            || stop.code.localizedCaseInsensitiveContains(trimmed)
    }

    private func accessibilityLabel(for stop: LiveMapStop) -> String {
        var pieces = [stop.name, stop.city]
        if stop.current { pieces.append("active visit") }
        if stop.home { pieces.append("home rink") }
        if stop.upcoming { pieces.append("upcoming") }
        return pieces.joined(separator: ", ")
    }
}

private struct LiveMapPin: View {
    @EnvironmentObject var settings: AppSettings
    let stop: LiveMapStop
    let selected: Bool
    let dimmed: Bool
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if stop.current {
                    Circle()
                        .stroke(settings.accent.opacity(0.45), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .scaleEffect(pulse ? 2.15 : 0.65)
                        .opacity(pulse ? 0 : 1)
                        .onAppear { pulse = true }
                        .animation(.easeOut(duration: 2.1).repeatForever(autoreverses: false), value: pulse)
                }

                HouseRing(size: stop.current ? 22 : (selected ? 34 : (stop.home ? 20 : 18)))
                    .padding(selected ? 3 : 0)
                    .background(selected ? Color.white : Color.clear)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.38), radius: 6, y: 2)
            }

            if selected || stop.current || stop.home {
                Text(stop.current ? "Active" : (stop.home ? "Home" : stop.code))
                    .font(.grotesk(10, .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(stop.home && !stop.current ? settings.ink : settings.accent)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            }
        }
        .opacity(dimmed ? 0.14 : 1)
        .allowsHitTesting(!dimmed)
    }
}

private struct LiveMapStopReadout: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let stop: LiveMapStop

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stop.code)
                            .font(.mono(11, .bold))
                            .tracking(1.6)
                            .foregroundStyle(settings.accent)
                        Text(stop.name)
                            .font(.serif(34))
                            .foregroundStyle(settings.ink)
                        Text(stop.meta)
                            .font(.mono(11, .medium))
                            .tracking(0.9)
                            .foregroundStyle(settings.muted)
                    }

                    HStack(spacing: 9) {
                        readoutMetric(stop.record, "Record", accent: true)
                        readoutMetric(stop.speed, "Speed")
                        readoutMetric(stop.curl, "Curl")
                        readoutMetric(stop.met, "Met")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "People you met here")
                        if stop.people.isEmpty {
                            Text(stop.peopleLabel)
                                .font(.grotesk(14, .medium))
                                .foregroundStyle(settings.muted)
                        } else {
                            HStack(spacing: -8) {
                                ForEach(stop.people, id: \.self) { person in
                                    AvatarView(initials: person, size: 40)
                                        .overlay(Circle().strokeBorder(settings.card, lineWidth: 1.5))
                                }
                            }
                            Text(stop.peopleLabel)
                                .font(.grotesk(14, .medium))
                                .foregroundStyle(settings.muted)
                        }
                    }
                    .padding(14)
                    .cpCard()
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(settings.screen)
            .navigationTitle("Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(settings.accent)
                }
            }
        }
        .presentationBackground(settings.screen)
    }

    private func readoutMetric(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.serif(20))
                .foregroundStyle(accent ? settings.accent : settings.ink)
            Text(label.uppercased())
                .font(.mono(8, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 11)
        .background(settings.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum LiveStopFilter: String, CaseIterable, Identifiable {
    case all
    case wins
    case upcoming
    case home

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All stops"
        case .wins: return "Wins"
        case .upcoming: return "Upcoming"
        case .home: return "Home rink"
        }
    }

    func includes(_ stop: LiveMapStop) -> Bool {
        switch self {
        case .all: return true
        case .wins: return stop.win
        case .upcoming: return stop.upcoming
        case .home: return stop.home
        }
    }
}

private enum LiveRouteMode: String, CaseIterable, Identifiable {
    case order
    case home
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .order: return "Travel order"
        case .home: return "From home"
        case .off: return "Off"
        }
    }

    var next: LiveRouteMode {
        switch self {
        case .order: return .home
        case .home: return .off
        case .off: return .order
        }
    }
}

private struct RouteGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 4))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 3))
        return path
    }
}

private struct LiveMapStop: Identifiable {
    let id: String
    let code: String
    let name: String
    let city: String
    let coordinate: CLLocationCoordinate2D
    let meta: String
    let record: String
    let speed: String
    let curl: String
    let games: String
    let met: String
    let home: Bool
    let win: Bool
    let upcoming: Bool
    let current: Bool
    let people: [String]
    let peopleLabel: String

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.05, longitude: -108.3),
        span: MKCoordinateSpan(latitudeDelta: 8.7, longitudeDelta: 28.5)
    )
}

private extension Store {
    var liveMapStops: [LiveMapStop] {
        stops.map { stop in
            let metIDs = peopleMetIDs(for: stop.id)
            let people = initials(for: metIDs, limit: 4)
            let names = metIDs.compactMap { curler($0)?.name }
            let peopleLabel: String
            if names.isEmpty {
                peopleLabel = isCurrentStop(stop.id) ? "Active visit without logged connections" : "No connections logged yet"
            } else if names.count <= 2 {
                peopleLabel = names.joined(separator: " & ")
            } else {
                peopleLabel = "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
            }

            let results = stopResults(stop.id)
            let recordWins = results.filter { $0.res == "WIN" || $0.res == "W" }.count + stop.games.filter { $0.res == "W" }.count
            let recordLosses = results.filter { $0.res == "LOSS" || $0.res == "L" }.count + stop.games.filter { $0.res == "L" }.count
            let hasWinningRecord = recordWins > recordLosses
            let coordinate = LiveMapStop.coordinate(for: stop)
            let gameCount = results.isEmpty ? stop.games.count : results.count

            return LiveMapStop(id: stop.id,
                               code: stop.code,
                               name: stop.name,
                               city: "\(stop.club), \(stop.prov)",
                               coordinate: coordinate,
                               meta: "\(stop.club.uppercased()) · \(stop.dates)",
                               record: stop.record,
                               speed: stop.iceSpeed,
                               curl: stop.iceCurl == "—" ? "—" : "\(stop.iceCurl)ft",
                               games: gameCount == 0 ? "—" : "\(gameCount)",
                               met: metIDs.isEmpty ? "—" : "\(metIDs.count)",
                               home: stop.club.localizedCaseInsensitiveContains(profile.homeClub),
                               win: hasWinningRecord,
                               upcoming: gameCount == 0 && !isCurrentStop(stop.id),
                               current: isCurrentStop(stop.id),
                               people: people,
                               peopleLabel: peopleLabel)
        }
    }
}

private extension LiveMapStop {
    static func coordinate(for stop: Stop) -> CLLocationCoordinate2D {
        if let latitude = stop.latitude, let longitude = stop.longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        if let known = knownCoordinates[stop.id] { return known }
        let lat = 48.8 + (stop.y / 100.0) * 5.2
        let lon = -122.4 + (stop.x / 100.0) * 25.6
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static let knownCoordinates: [String: CLLocationCoordinate2D] = [
        "kamloops": CLLocationCoordinate2D(latitude: 50.6745, longitude: -120.3273),
        "kelowna": CLLocationCoordinate2D(latitude: 49.8880, longitude: -119.4960),
        "vernon": CLLocationCoordinate2D(latitude: 50.2670, longitude: -119.2720),
        "calgary": CLLocationCoordinate2D(latitude: 51.0447, longitude: -114.0719),
        "winnipeg": CLLocationCoordinate2D(latitude: 49.8951, longitude: -97.1384)
    ]
}
