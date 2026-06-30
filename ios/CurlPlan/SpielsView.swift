import MapKit
import SwiftUI

struct SpielsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNew = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spiels").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
                Button { showingNew = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(settings.ink)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add spiel")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .cpReadableContent()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your season ahead")
                    if store.spiels.isEmpty {
                        EmptyStateView(title: "No spiels yet",
                                       message: "Add a bonspiel to start planning the season ahead.",
                                       systemImage: "calendar.badge.plus",
                                       actionTitle: "New spiel") {
                            showingNew = true
                        }
                    } else {
                        ForEach(store.spiels) { sp in
                            SpielRow(spiel: sp)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
                .cpReadableContent()
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNew) { NewSpielSheet() }
    }
}

struct NewSpielSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var venueSearch = VenueSearchModel()
    @State private var name = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var status = "You're in"
    @State private var discipline = CurlingDiscipline.fourPlayer.label
    @State private var selectedVenue: Venue?
    @State private var resolvingVenue = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate && !resolvingVenue
    }

    private var validationMessage: String? {
        if resolvingVenue { return "Resolving venue..." }
        return endDate < startDate ? "End date must be on or after start date." : nil
    }

    private var curatedSuggestions: [Venue] {
        store.venueSuggestions(for: location, limit: 4)
    }

    var body: some View {
        CreateScaffold(title: "New spiel",
                       subtitle: "Add a bonspiel to your season ahead.",
                       canSave: canSave,
                       validationMessage: validationMessage,
                       onCancel: { dismiss() },
                       onSave: save) {
            CPField(label: "Name", text: $name, placeholder: "Brier Patch Open")
            VenueLocationField(location: $location,
                               selectedVenue: selectedVenue,
                               curatedSuggestions: curatedSuggestions,
                               mapSuggestions: venueSearch.suggestions,
                               isSearching: venueSearch.isSearching,
                               resolvingVenue: resolvingVenue,
                               onVenueSelect: selectVenue,
                               onMapSelect: selectMapSuggestion)
            HStack(spacing: 10) {
                CPDateField(label: "Start", date: $startDate)
                CPDateField(label: "End", date: $endDate)
            }
            CPChips(label: "Your status", options: ["You're in", "Watching", "Invite"], selection: $status)
            CPChips(label: "Discipline", options: CurlingDiscipline.allCases.map(\.label), selection: $discipline)
        }
        .onAppear { venueSearch.update(query: location) }
        .onChange(of: location) { _, newValue in
            if let selectedVenue,
               !VenueResolver.matches(selectedVenue, query: newValue),
               VenueResolver.normalized(newValue) != VenueResolver.normalized(selectedVenue.displayName) {
                self.selectedVenue = nil
            }
            venueSearch.update(query: newValue)
        }
    }

    private func selectVenue(_ venue: Venue) {
        selectedVenue = venue
        location = venue.displayName
    }

    private func selectMapSuggestion(_ suggestion: VenueSearchSuggestion) {
        resolvingVenue = true
        Task {
            let venue = await VenueSearchModel.resolve(suggestion)
            await MainActor.run {
                resolvingVenue = false
                if let venue {
                    selectVenue(venue)
                }
            }
        }
    }

    private func save() {
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVenue = selectedVenue ?? VenueResolver.resolve(cleanLocation, venues: store.venues)
        if let resolvedVenue {
            commit(venue: resolvedVenue)
            return
        }
        guard !cleanLocation.isEmpty else {
            commit(venue: nil)
            return
        }

        resolvingVenue = true
        Task {
            let geocodedVenue = await VenueSearchModel.geocode(cleanLocation)
            await MainActor.run {
                resolvingVenue = false
                commit(venue: geocodedVenue)
            }
        }
    }

    private func commit(venue: Venue?) {
        store.addSpiel(name: name.trimmingCharacters(in: .whitespaces),
                       whereText: location.trimmingCharacters(in: .whitespaces),
                       startDate: startDate,
                       endDate: endDate,
                       status: status,
                       discipline: CurlingDiscipline.fromLabel(discipline),
                       venue: venue)
        dismiss()
    }
}

private struct VenueLocationField: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var location: String
    let selectedVenue: Venue?
    let curatedSuggestions: [Venue]
    let mapSuggestions: [VenueSearchSuggestion]
    let isSearching: Bool
    let resolvingVenue: Bool
    let onVenueSelect: (Venue) -> Void
    let onMapSelect: (VenueSearchSuggestion) -> Void

    private var visibleMapSuggestions: [VenueSearchSuggestion] {
        Array(mapSuggestions.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCATION")
                .font(.mono(10, .medium))
                .tracking(1.5)
                .foregroundStyle(settings.muted)

            HStack(spacing: 9) {
                TextField("Kamloops, BC", text: $location)
                    .font(.grotesk(15))
                    .foregroundStyle(settings.ink)
                    .tint(settings.accent)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("curlplan.field.location")
                if resolvingVenue || isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(settings.accent)
                } else if selectedVenue != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(settings.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(settings.line, lineWidth: 1))

            if selectedVenue != nil || !curatedSuggestions.isEmpty || !visibleMapSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(curatedSuggestions) { venue in
                        VenueSuggestionRow(title: venue.displayName,
                                           subtitle: subtitle(for: venue),
                                           systemImage: "mappin.and.ellipse",
                                           selected: selectedVenue?.id == venue.id) {
                            onVenueSelect(venue)
                        }
                    }
                    ForEach(visibleMapSuggestions) { suggestion in
                        VenueSuggestionRow(title: suggestion.title,
                                           subtitle: suggestion.subtitle,
                                           systemImage: "map",
                                           selected: false) {
                            onMapSelect(suggestion)
                        }
                    }
                }
                .background(settings.panel.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(settings.line, lineWidth: 1))
            }
        }
    }

    private func subtitle(for venue: Venue) -> String {
        let location = venue.displayLocationText
        let authority = venue.authority.label
        return location.isEmpty ? authority : "\(location) · \(authority)"
    }
}

private struct VenueSuggestionRow: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    let subtitle: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? settings.accent : settings.muted)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.grotesk(13, .semibold))
                        .foregroundStyle(settings.ink)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.grotesk(11))
                            .foregroundStyle(settings.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct VenueSearchSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        id = Venue.generatedID(prefix: "venue-search", name: title, city: subtitle)
    }

    var queryText: String {
        [title, subtitle].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

private final class VenueSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [VenueSearchSuggestion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var lastQuery = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = Self.searchRegion
    }

    func update(query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else {
            lastQuery = ""
            suggestions = []
            isSearching = false
            completer.queryFragment = ""
            return
        }
        guard clean != lastQuery else { return }
        lastQuery = clean
        isSearching = true
        completer.queryFragment = clean
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.reduce(into: [VenueSearchSuggestion]()) { result, completion in
            let suggestion = VenueSearchSuggestion(title: completion.title, subtitle: completion.subtitle)
            guard !result.contains(where: { $0.id == suggestion.id }) else { return }
            result.append(suggestion)
        }
        DispatchQueue.main.async {
            self.suggestions = Array(mapped.prefix(6))
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.isSearching = false
        }
    }

    static func resolve(_ suggestion: VenueSearchSuggestion) async -> Venue? {
        await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = suggestion.queryText
            request.region = searchRegion
            MKLocalSearch(request: request).start { response, _ in
                let venue = response?.mapItems.compactMap { Venue.mapItem($0, fallbackName: suggestion.title) }.first
                continuation.resume(returning: venue)
            }
        }
    }

    static func geocode(_ query: String) async -> Venue? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(query) { placemarks, _ in
                let venue = placemarks?.compactMap { Venue.geocoded($0, fallbackName: query) }.first
                continuation.resume(returning: venue)
            }
        }
    }

    private static let searchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.0, longitude: -106.0),
        span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 70)
    )
}

private extension VenueAuthority {
    var label: String {
        switch self {
        case .curated: return "Curated"
        case .mapItem: return "Apple Maps"
        case .geocodedAddress: return "Geocoded"
        case .freeText: return "Free text"
        case .unmapped: return "Unmapped"
        }
    }
}

private extension Venue {
    static func mapItem(_ item: MKMapItem, fallbackName: String) -> Venue? {
        let placemark = item.placemark
        guard CLLocationCoordinate2DIsValid(placemark.coordinate) else { return nil }
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? item.name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : fallbackName
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        let region = placemark.administrativeArea ?? ""
        let country = placemark.isoCountryCode ?? "CA"
        return Venue(id: Venue.generatedID(prefix: "venue-map", name: name, city: city, region: region),
                     displayName: name,
                     aliases: [fallbackName, placemark.title].compactMap { $0 }.filter { !$0.isEmpty },
                     clubName: name,
                     city: city,
                     region: region,
                     country: country,
                     postalAddress: formattedAddress(placemark),
                     latitude: placemark.coordinate.latitude,
                     longitude: placemark.coordinate.longitude,
                     timezone: placemark.timeZone?.identifier,
                     authority: .mapItem)
    }

    static func geocoded(_ placemark: CLPlacemark, fallbackName: String) -> Venue? {
        guard let location = placemark.location,
              CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? placemark.name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : fallbackName
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
        let region = placemark.administrativeArea ?? ""
        let country = placemark.isoCountryCode ?? "CA"
        return Venue(id: Venue.generatedID(prefix: "venue-geocoded", name: name, city: city, region: region),
                     displayName: name,
                     aliases: [fallbackName],
                     clubName: name,
                     city: city,
                     region: region,
                     country: country,
                     postalAddress: formattedAddress(placemark),
                     latitude: location.coordinate.latitude,
                     longitude: location.coordinate.longitude,
                     timezone: placemark.timeZone?.identifier,
                     authority: .geocodedAddress)
    }

    private static func formattedAddress(_ placemark: CLPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [street, placemark.locality, placemark.administrativeArea, placemark.postalCode, placemark.isoCountryCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

private struct CPDateField: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.mono(10, .medium))
                .tracking(1.5)
                .foregroundStyle(settings.muted)
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(settings.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(settings.line, lineWidth: 1))
                .accessibilityIdentifier("curlplan.date.\(label.lowercased())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpielRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingDetail = false
    let spiel: Spiel

    var body: some View {
        let solid = spiel.status == "You're in"
        let bonspiel = store.bonspiel(for: spiel.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                    Text(spiel.name).font(.serif(21)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted).padding(.top, 2)
                    if let bonspiel {
                        Text("\(bonspiel.discipline.label.uppercased()) · \(bonspiel.rulesProfile.scheduledEnds) ENDS · LINEUP LOCK \(bonspiel.rosterPolicy.lockMinutesBeforeGame) MIN")
                            .font(.mono(9, .medium))
                            .tracking(1)
                            .foregroundStyle(settings.muted)
                            .padding(.top, 3)
                    }
                }
                Spacer()
                Text(spiel.status)
                    .font(solid ? .mono(9, .bold) : .grotesk(11, .semibold))
                    .tracking(solid ? 1 : 0)
                    .foregroundStyle(solid ? .white : settings.muted)
                    .padding(.vertical, solid ? 4 : 5)
                    .padding(.horizontal, solid ? 8 : 10)
                    .background(solid ? settings.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous)
                            .strokeBorder(solid ? Color.clear : settings.line, lineWidth: 1)
                    )
            }

            HStack(spacing: 11) {
                let attendeeIDs = store.attendeeIDs(for: spiel.id)
                AvatarStack(initials: store.initials(for: attendeeIDs, limit: 4), size: 28, plus: store.plusLabel(for: attendeeIDs, visible: 4))
                Text("\(attendeeIDs.count) attending")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                PillButton(title: "Details", filled: false) { showingDetail = true }
                    .accessibilityIdentifier("curlplan.spiel.details.\(spiel.id)")
            }
        }
        .padding(14)
        .cpCard()
        .sheet(isPresented: $showingDetail) { SpielDetailSheet(spielID: spiel.id) }
    }
}

struct SpielDetailSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let spielID: String

    private let statuses = ["You're in", "Watching", "Invite"]

    var body: some View {
        Group {
            if let spiel = store.spiels.first(where: { $0.id == spielID }) {
                VStack(alignment: .leading, spacing: 0) {
                    Capsule().fill(settings.line).frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                            Text(spiel.name).font(.serif(26)).foregroundStyle(settings.ink)
                            Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted)
                                .padding(.top, -10)

                            Text("YOUR STATUS").font(.mono(10, .medium)).tracking(1.5)
                                .foregroundStyle(settings.muted).padding(.bottom, -8)
                            HStack(spacing: 8) {
                                ForEach(statuses, id: \.self) { opt in
                                    let on = spiel.status == opt
                                    Button { store.setSpielStatus(spiel.id, opt) } label: {
                                        Text(opt).font(.grotesk(12, .semibold))
                                            .foregroundStyle(on ? .white : settings.ink)
                                            .padding(.vertical, 9).padding(.horizontal, 14)
                                            .background(on ? settings.accent : settings.panel)
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer(minLength: 0)
                            }

                            if let bonspiel = store.bonspiel(for: spiel.id) {
                                BonspielSummaryCard(record: bonspiel)
                                BonspielRosterCard(record: bonspiel)
                                BonspielGamesCard(record: bonspiel)
                            }

                            let attendeeIDs = store.attendeeIDs(for: spiel.id)
                            Text("\(attendeeIDs.count) ATTENDING").font(.mono(10, .medium))
                                .tracking(1.5).foregroundStyle(settings.muted)
                            if attendeeIDs.isEmpty {
                                Text("No attendance recorded yet.")
                                    .font(.grotesk(13)).foregroundStyle(settings.muted)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(attendeeIDs, id: \.self) { id in
                                        if id == "me" {
                                            HStack(spacing: 11) {
                                                AvatarView(initials: store.me.initials, size: 36)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(store.me.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                                                    Text("YOU")
                                                        .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                                }
                                                Spacer()
                                            }
                                        } else if let c = store.curler(id) {
                                            HStack(spacing: 11) {
                                                AvatarView(initials: c.initials, size: 36)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(c.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                                                    Text("\(c.role.uppercased()) · \(c.club.uppercased())")
                                                        .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    }

                    Button { dismiss() } label: {
                        Text("Done").font(.grotesk(14, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(settings.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(settings.card)
            } else {
                settings.card
            }
        }
    }
}

private struct BonspielSummaryCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bonspiel record")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric("Discipline", record.discipline.label)
                metric("Rules", record.rulesProfile.rulebookRef)
                metric("Ends", "\(record.rulesProfile.scheduledEnds)")
                metric("Dates", record.startDate == record.endDate ? record.startDate : "\(record.startDate) to \(record.endDate)")
                metric("Timezone", record.timezone)
                metric("Venue source", venueSource)
            }
            Text("\(record.venue.name) · \(record.venue.display)")
                .font(.grotesk(13, .semibold))
                .foregroundStyle(settings.ink)
            Text("Roster fields: \(record.privacyPolicy.rosterDisplayFields.joined(separator: ", "))")
                .font(.mono(10, .medium))
                .foregroundStyle(settings.muted)
        }
        .padding(14)
        .cpCard(radius: 16)
    }

    private var venueSource: String {
        guard let venueID = record.venueID, let venue = store.venue(venueID) else { return "Free text" }
        return venue.canMap ? "\(venue.authority.label) coordinates" : venue.authority.label
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.mono(9, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
            Text(value)
                .font(.grotesk(13, .bold))
                .foregroundStyle(settings.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(settings.panel)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct BonspielRosterCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var addingToTeam: BonspielTeam?
    @State private var actionMessage: String?
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Roster policy", action: "\(record.rosterPolicy.lockMinutesBeforeGame) min lock")
            HStack(spacing: 8) {
                rosterPill("\(record.rosterPolicy.maxPlayersOnIce) on ice")
                rosterPill(record.rosterPolicy.allowAlternates ? "Alternates" : "No alternates")
                rosterPill(record.rosterPolicy.allowSpares ? "Spares" : "No spares")
            }
            .fixedSize(horizontal: false, vertical: true)
            if record.teams.isEmpty {
                Text("No team roster captured yet.")
                    .font(.grotesk(13))
                    .foregroundStyle(settings.muted)
            } else {
                ForEach(record.teams.prefix(2)) { team in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(team.displayName)
                                .font(.grotesk(14, .bold))
                                .foregroundStyle(settings.ink)
                            Spacer()
                            Button {
                                addingToTeam = team
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(settings.accent)
                                    .frame(width: 28, height: 28)
                                    .background(settings.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add member to \(team.displayName)")
                            .accessibilityIdentifier("curlplan.bonspiel.roster.add.\(team.id)")
                        }
                        ForEach(team.members) { member in
                            HStack {
                                Text(member.declaredPosition)
                                    .font(.mono(9, .medium))
                                    .foregroundStyle(settings.muted)
                                    .frame(width: 48, alignment: .leading)
                                Text(member.displayName)
                                    .font(.grotesk(12, .semibold))
                                    .foregroundStyle(settings.ink)
                                Spacer()
                                Text(member.rosterStatus.uppercased())
                                    .font(.mono(8, .bold))
                                    .foregroundStyle(settings.muted)
                                Button {
                                    actionMessage = store.removeBonspielTeamMember(bonspielID: record.id,
                                                                                   teamID: team.id,
                                                                                   memberID: member.id).userMessage
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(settings.houseRed)
                                        .frame(width: 26, height: 26)
                                        .background(settings.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(member.displayName)")
                                .accessibilityIdentifier("curlplan.bonspiel.roster.remove.\(member.id)")
                            }
                        }
                    }
                    .padding(10)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if let actionMessage {
                Text(actionMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("curlplan.bonspiel.roster.message")
            }
        }
        .padding(14)
        .cpCard(radius: 16)
        .sheet(item: $addingToTeam) { team in
            BonspielTeamMemberSheet(recordID: record.id, teamID: team.id) { receipt in
                actionMessage = receipt.userMessage
            }
        }
    }

    private func rosterPill(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.mono(9, .medium))
            .tracking(0.8)
            .foregroundStyle(settings.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BonspielTeamMemberSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let recordID: String
    let teamID: String
    let onReceipt: (MutationReceipt) -> Void
    @State private var name = ""
    @State private var position = "Lead"
    @State private var status = "active"
    @State private var role = "player"

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        CreateScaffold(title: "Team member",
                       subtitle: "Add a local roster member for this bonspiel team.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           let receipt = store.addBonspielTeamMember(bonspielID: recordID,
                                                                      teamID: teamID,
                                                                      displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                      role: role,
                                                                      rosterStatus: status,
                                                                      declaredPosition: position)
                           onReceipt(receipt)
                           dismiss()
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Lineup Spare")
            CPChips(label: "Position", options: ["Lead", "Second", "Third", "Fourth", "Alternate"], selection: $position)
            CPChips(label: "Status", options: ["active", "alternate", "spare"], selection: $status)
            CPField(label: "Role", text: $role, placeholder: "player")
        }
    }
}

private struct BonspielGameSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let record: BonspielRecord
    let onReceipt: (MutationReceipt) -> Void
    @State private var drawLabel: String
    @State private var scheduledStartAt: String
    @State private var sheet: String
    @State private var opponentName = ""

    init(record: BonspielRecord, onReceipt: @escaping (MutationReceipt) -> Void) {
        self.record = record
        self.onReceipt = onReceipt
        _drawLabel = State(initialValue: "Draw \(record.games.count + 1)")
        _scheduledStartAt = State(initialValue: Self.defaultScheduledStart(for: record))
        _sheet = State(initialValue: "Sheet A")
    }

    private var validationMessage: String? {
        canSave ? nil : "Draw, scheduled start, sheet, and opponent are required."
    }

    private var canSave: Bool {
        !drawLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !scheduledStartAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sheet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        CreateScaffold(title: "New game",
                       subtitle: "Create a local draw and sheet snapshot for this bonspiel.",
                       canSave: canSave,
                       validationMessage: validationMessage,
                       onCancel: { dismiss() },
                       onSave: save) {
            CPField(label: "Draw", text: $drawLabel, placeholder: "Draw 1")
            CPField(label: "Scheduled start", text: $scheduledStartAt, placeholder: "2026-02-14 10:00")
            CPField(label: "Sheet", text: $sheet, placeholder: "Sheet A")
            CPField(label: "Opponent", text: $opponentName, placeholder: "Team Northern")
        }
    }

    private func save() {
        let receipt = store.addBonspielGame(bonspielID: record.id,
                                            drawLabel: drawLabel,
                                            scheduledStartAt: scheduledStartAt,
                                            sheet: sheet,
                                            opponentName: opponentName)
        onReceipt(receipt)
        dismiss()
    }

    private static func defaultScheduledStart(for record: BonspielRecord) -> String {
        let start = record.startDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if start.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return "\(start) 10:00"
        }
        return start == "Date TBD" ? "" : start
    }
}

private struct BonspielGamesCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNewGame = false
    @State private var editingScoreGame: BonspielGame?
    @State private var actionMessage: String?
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Game snapshots",
                          action: "New game",
                          actionAccessibilityLabel: "Add local bonspiel game") {
                showingNewGame = true
            }
            if record.games.isEmpty {
                Text("No local games created yet.")
                    .font(.grotesk(13))
                    .foregroundStyle(settings.muted)
            } else {
                ForEach(record.games.prefix(3)) { game in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(game.drawLabel) · \(game.sheet)")
                                    .font(.mono(10, .medium))
                                    .tracking(1)
                                    .foregroundStyle(settings.muted)
                                Text("\(record.teamName(game.teamAID)) vs \(record.teamName(game.teamBID))")
                                    .font(.grotesk(14, .bold))
                                    .foregroundStyle(settings.ink)
                            }
                            Spacer()
                            Text(game.scoreLabel)
                                .font(.serif(20))
                                .foregroundStyle(settings.ink)
                                .accessibilityIdentifier("curlplan.bonspiel.\(game.id).score")
                        }
                        HStack(spacing: 5) {
                            ForEach(game.ends) { end in
                                VStack(spacing: 3) {
                                    Text("\(end.endNumber)")
                                        .font(.mono(8, .medium))
                                        .foregroundStyle(settings.muted)
                                    Text(end.isBlank ? "0" : "\(max(end.teamA, end.teamB))")
                                        .font(.mono(10, .bold))
                                        .foregroundStyle(end.isBlank ? settings.muted : settings.ink)
                                }
                                .frame(width: 26, height: 34)
                                .background(settings.card)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                        Text("LSFE: \(record.teamName(game.lsfeOrPlacementDecision.teamID)) · \(game.status.label)")
                            .font(.mono(10, .medium))
                            .foregroundStyle(settings.muted)
                            .accessibilityIdentifier("curlplan.bonspiel.\(game.id).status")
                        ForEach(game.gameLineups.prefix(2)) { lineup in
                            Text("\(record.teamName(lineup.teamID)): \(record.lineupNames(lineup).joined(separator: ", "))")
                                .font(.grotesk(11, .semibold))
                                .foregroundStyle(settings.muted)
                                .lineLimit(2)
                        }
                        gameControls(game)
                    }
                    .padding(11)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if let actionMessage {
                Text(actionMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("curlplan.bonspiel.games.message")
            }
        }
        .padding(14)
        .cpCard(radius: 16)
        .sheet(isPresented: $showingNewGame) {
            BonspielGameSheet(record: record) { receipt in
                actionMessage = receipt.userMessage
            }
        }
        .sheet(item: $editingScoreGame) { game in
            BonspielScoreEditSheet(record: record, game: game) { receipt in
                actionMessage = receipt.userMessage
            }
        }
    }

    private func gameControls(_ game: BonspielGame) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text(store.scorecardValidationMessage(bonspielID: record.id, gameID: game.id) ?? "Scorecard can be locally confirmed.")
                .font(.mono(9, .medium))
                .foregroundStyle(game.scoreAgreement.confirmed ? settings.accent : settings.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("curlplan.bonspiel.\(game.id).validation")

            lineupControls(game)

            if !game.scoreAgreement.confirmed {
                HStack(spacing: 6) {
                    gameActionButton("Edit end", id: "curlplan.bonspiel.\(game.id).editScore") {
                        editingScoreGame = game
                    }
                    gameActionButton("A +1", id: "curlplan.bonspiel.\(game.id).scoreA") {
                        recordNextEnd(game, teamA: 1, teamB: 0, isBlank: false)
                    }
                    gameActionButton("Blank", id: "curlplan.bonspiel.\(game.id).blank") {
                        recordNextEnd(game, teamA: 0, teamB: 0, isBlank: true)
                    }
                    gameActionButton("B +1", id: "curlplan.bonspiel.\(game.id).scoreB") {
                        recordNextEnd(game, teamA: 0, teamB: 1, isBlank: false)
                    }
                }

                HStack(spacing: 6) {
                    gameActionButton("Concede", id: "curlplan.bonspiel.\(game.id).concede") {
                        actionMessage = store.setBonspielResultFlags(bonspielID: record.id,
                                                                      gameID: game.id,
                                                                      conceded: true,
                                                                      forfeited: false).userMessage
                    }
                    gameActionButton("Forfeit", id: "curlplan.bonspiel.\(game.id).forfeit") {
                        actionMessage = store.setBonspielResultFlags(bonspielID: record.id,
                                                                      gameID: game.id,
                                                                      conceded: false,
                                                                      forfeited: true).userMessage
                    }
                    gameActionButton("Confirm", id: "curlplan.bonspiel.\(game.id).confirm") {
                        actionMessage = store.confirmBonspielGameResult(bonspielID: record.id, gameID: game.id).userMessage
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Text("Local result confirmed")
                        .font(.mono(10, .bold))
                        .foregroundStyle(settings.accent)
                    Spacer()
                    gameActionButton("Correct score", id: "curlplan.bonspiel.\(game.id).correctScore") {
                        editingScoreGame = game
                    }
                    .frame(maxWidth: 118)
                }
            }
        }
    }

    private func lineupControls(_ game: BonspielGame) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCAL LINEUP")
                .font(.mono(9, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
            if store.lineupIsLocked(bonspielID: record.id, gameID: game.id) {
                HStack(spacing: 6) {
                    gameActionButton("Try A lineup", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID)
                    }
                    gameActionButton("Try B lineup", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamBID)") {
                        submitDefaultLineup(game, teamID: game.teamBID)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    gameActionButton("Invalid A", id: "curlplan.bonspiel.\(game.id).invalid.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID, invalid: true)
                    }
                    gameActionButton("Submit A", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID)
                    }
                }
                HStack(spacing: 6) {
                    gameActionButton("Submit B", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamBID)") {
                        submitDefaultLineup(game, teamID: game.teamBID)
                    }
                    gameActionButton("Lock lineup", id: "curlplan.bonspiel.\(game.id).lockLineup") {
                        actionMessage = store.lockBonspielLineup(bonspielID: record.id, gameID: game.id).userMessage
                    }
                }
            }
        }
    }

    private func gameActionButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(9, .bold))
                .foregroundStyle(settings.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(settings.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func submitDefaultLineup(_ game: BonspielGame, teamID: String, invalid: Bool = false) {
        guard let team = record.teams.first(where: { $0.id == teamID }) else {
            actionMessage = "Bonspiel team not found."
            return
        }
        let required = record.rosterPolicy.maxPlayersOnIce
        let count = invalid ? max(required - 1, 0) : required
        let positions = ["Lead", "Second", "Third", "Fourth", "Fifth"]
        let members = Array(team.members.prefix(count))
        let slots = members.enumerated().map { index, member in
            BonspielLineupSlot(memberID: member.id,
                               position: positions[min(index, positions.count - 1)],
                               isSkip: index == members.count - 1,
                               isViceSkip: members.count > 1 && index == members.count - 2)
        }
        actionMessage = store.submitBonspielLineup(bonspielID: record.id,
                                                   gameID: game.id,
                                                   teamID: teamID,
                                                   slots: slots).userMessage
    }

    private func recordNextEnd(_ game: BonspielGame, teamA: Int, teamB: Int, isBlank: Bool) {
        let nextEnd = (game.ends.map(\.endNumber).max() ?? 0) + 1
        let receipt = store.recordBonspielEndScore(bonspielID: record.id,
                                                   gameID: game.id,
                                                   endNumber: nextEnd,
                                                   teamA: teamA,
                                                   teamB: teamB,
                                                   isBlank: isBlank,
                                                   isExtraEnd: nextEnd > game.scheduledEnds)
        actionMessage = receipt.userMessage
    }
}

private struct BonspielScoreEditSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let record: BonspielRecord
    let game: BonspielGame
    let onReceipt: (MutationReceipt) -> Void
    @State private var endNumber: String
    @State private var scoringSide: String
    @State private var points: String
    @State private var endType: String

    init(record: BonspielRecord, game: BonspielGame, onReceipt: @escaping (MutationReceipt) -> Void) {
        self.record = record
        self.game = game
        self.onReceipt = onReceipt
        let nextEnd = (game.ends.map(\.endNumber).max() ?? 0) + 1
        let suggestedEnd = min(max(nextEnd, 1), game.scheduledEnds)
        let existing = game.ends.first(where: { $0.endNumber == suggestedEnd })
        _endNumber = State(initialValue: "\(existing?.endNumber ?? suggestedEnd)")
        if let existing {
            if existing.isBlank {
                _scoringSide = State(initialValue: "Blank")
                _points = State(initialValue: "1")
            } else if existing.teamA > 0 {
                _scoringSide = State(initialValue: "Team A")
                _points = State(initialValue: "\(existing.teamA)")
            } else {
                _scoringSide = State(initialValue: "Team B")
                _points = State(initialValue: "\(existing.teamB)")
            }
            _endType = State(initialValue: existing.isExtraEnd ? "Extra" : "Regulation")
        } else {
            _scoringSide = State(initialValue: "Team A")
            _points = State(initialValue: "1")
            _endType = State(initialValue: suggestedEnd > game.scheduledEnds ? "Extra" : "Regulation")
        }
    }

    private var endNumberValue: Int? {
        Int(endNumber.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var pointsValue: Int? {
        Int(points.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var validationMessage: String? {
        guard let endNumberValue, endNumberValue > 0 else { return "End number must be positive." }
        if scoringSide != "Blank" {
            guard let pointsValue, pointsValue > 0 else { return "Scoring end needs points." }
        }
        return nil
    }

    private var canSave: Bool { validationMessage == nil }

    var body: some View {
        CreateScaffold(title: game.scoreAgreement.confirmed ? "Correct score" : "Edit score",
                       subtitle: "Update one local end. Confirm the scorecard again after a correction.",
                       canSave: canSave,
                       validationMessage: validationMessage,
                       onCancel: { dismiss() },
                       onSave: save) {
            CPField(label: "End", text: $endNumber, placeholder: "1", keyboard: .numberPad)
            CPChips(label: "Scored by", options: ["Team A", "Blank", "Team B"], selection: $scoringSide)
            if scoringSide != "Blank" {
                CPField(label: "Points", text: $points, placeholder: "1", keyboard: .numberPad)
            }
            CPChips(label: "End type", options: ["Regulation", "Extra"], selection: $endType)
        }
    }

    private func save() {
        guard let endNumberValue else { return }
        let pointsValue = scoringSide == "Blank" ? 0 : (self.pointsValue ?? 0)
        let teamA = scoringSide == "Team A" ? pointsValue : 0
        let teamB = scoringSide == "Team B" ? pointsValue : 0
        let isBlank = scoringSide == "Blank"
        let isExtraEnd = endType == "Extra" || endNumberValue > game.scheduledEnds
        let receipt: MutationReceipt
        if game.scoreAgreement.confirmed || game.status == .finalized || game.status == .forfeit {
            receipt = store.correctBonspielEndScore(bonspielID: record.id,
                                                    gameID: game.id,
                                                    endNumber: endNumberValue,
                                                    teamA: teamA,
                                                    teamB: teamB,
                                                    isBlank: isBlank,
                                                    isExtraEnd: isExtraEnd)
        } else {
            receipt = store.recordBonspielEndScore(bonspielID: record.id,
                                                   gameID: game.id,
                                                   endNumber: endNumberValue,
                                                   teamA: teamA,
                                                   teamB: teamB,
                                                   isBlank: isBlank,
                                                   isExtraEnd: isExtraEnd)
        }
        onReceipt(receipt)
        dismiss()
    }
}
