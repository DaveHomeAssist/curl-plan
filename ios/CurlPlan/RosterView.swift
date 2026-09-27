import SwiftUI

struct RosterView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNew = false
    @State private var searching = false
    @State private var query = ""

    private var filtered: [Curler] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.curlers }
        return store.curlers.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.club.localizedCaseInsensitiveContains(q) ||
            $0.role.localizedCaseInsensitiveContains(q) || ($0.rosterDetails?.summary ?? "Availability unknown").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Roster").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        withAnimation { searching.toggle() }
                        if !searching { query = "" }
                    } label: {
                        Image(systemName: searching ? "xmark" : "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(settings.ink)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search roster")
                    Button { showingNew = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(settings.ink)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add contact")
                    .accessibilityIdentifier("curlplan.roster.add")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(settings.muted)
                    TextField("Search your circle", text: $query)
                        .font(.grotesk(15)).foregroundStyle(settings.ink).tint(settings.accent)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(settings.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 9).padding(.horizontal, 13)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your circle · \(filtered.count) curler\(filtered.count == 1 ? "" : "s")")
                    if filtered.isEmpty {
                        Text("No curlers match \"\(query)\".")
                            .font(.grotesk(13)).foregroundStyle(settings.muted)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filtered) { c in
                                RosterRow(curler: c)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNew) { NewCurlerSheet() }
    }
}

struct NewCurlerSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let existing: Curler?
    @State private var name: String
    @State private var role: String
    @State private var club: String
    @State private var prov: String
    @State private var details: RosterDetails
    @State private var failed = false

    init(existing: Curler? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _role = State(initialValue: existing?.role == "Spare" ? "Curler" : existing?.role ?? "Skip")
        _club = State(initialValue: existing?.club ?? "")
        _prov = State(initialValue: existing?.prov ?? "")
        var d = existing?.rosterDetails ?? RosterDetails()
        if existing?.role == "Spare" { d.isSpare = true }
        _details = State(initialValue: d)
    }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && details.isValid }

    var body: some View {
        CreateScaffold(title: existing == nil ? "Add to roster" : "Edit contact",
                       subtitle: "Private notes on this device. Confirm availability directly; no invitation is sent. Cancel discards unsaved changes.",
                       canSave: canSave, onCancel: { dismiss() }, onSave: {
                           if store.saveRosterContact(id: existing?.id, name: name, role: role, club: club, prov: prov, details: details) { dismiss() }
                           else { failed = true }
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Sam Reid")
            CPChips(label: "Position", options: ["Skip", "Third", "Second", "Lead", "Curler"], selection: $role)
            CPField(label: "Club", text: $club, placeholder: "Vernon CC")
            CPField(label: "Province", text: $prov, placeholder: "BC")
            Toggle("Spare contact", isOn: $details.isSpare)
            CPField(label: "Contact details", text: $details.contact, placeholder: "Phone or email (private)")
            Picker("Availability note", selection: $details.availability) {
                ForEach(["Unknown", "Available", "Unavailable"], id: \.self) { Text($0) }
            }.accessibilityIdentifier("curlplan.roster.availability")
            .onChange(of: details.availability) { _, value in
                if value == "Unknown" { details.from = ""; details.through = "" }
            }
            if details.availability != "Unknown" {
                CPField(label: "Available from (YYYY-MM-DD)", text: $details.from, placeholder: "2026-10-01")
                CPField(label: "Through (YYYY-MM-DD)", text: $details.through, placeholder: "2026-10-03")
                if !details.isValid { Text("Enter real dates, with the end on or after the start.").font(.footnote) }
            }
            CPTextArea(label: "Availability notes", text: $details.notes)
        }
        .presentationDetents([.large])
        .alert("Could not save contact", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }
}

private struct RosterRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let curler: Curler

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    curlerLink
                    followButton
                }
            } else {
                HStack(spacing: 12) {
                    curlerLink
                    Spacer()
                    followButton
                }
            }
        }
        .padding(12)
        .cpCard()
    }

    private var curlerLink: some View {
        NavigationLink(value: Route.curler(curler.id)) {
            HStack(spacing: 12) {
                AvatarView(initials: curler.initials, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(curler.name).font(.grotesk(15, .bold)).foregroundStyle(settings.ink)
                    Text(curler.rosterDetails?.summary ?? "Availability unknown")
                        .font(.footnote).foregroundStyle(settings.muted).fixedSize(horizontal: false, vertical: true)
                    Text("\(curler.role.uppercased()) · \(curler.club.uppercased())")
                        .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("curlplan.curler.\(curler.id)")
    }

    private var followButton: some View {
        PillButton(title: store.isFollowing(curler.id) ? "Following" : "Follow",
                   filled: !store.isFollowing(curler.id)) {
            store.toggleFollow(curler.id)
        }
    }
}
