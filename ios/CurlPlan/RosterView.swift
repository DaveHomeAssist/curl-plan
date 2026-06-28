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
            $0.name.localizedCaseInsensitiveContains(q) || $0.club.localizedCaseInsensitiveContains(q)
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
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(searching ? "Close roster search" : "Search roster")
                    .accessibilityIdentifier("curlplan.roster.search")
                    Button { showingNew = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(settings.ink)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add curler")
                    .accessibilityIdentifier("curlplan.addCurler")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .cpReadableContent()

            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(settings.muted)
                    TextField("Search your circle", text: $query)
                        .font(.grotesk(15)).foregroundStyle(settings.ink).tint(settings.accent)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("curlplan.roster.searchField")
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
                .cpReadableContent()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your circle · \(filtered.count) curler\(filtered.count == 1 ? "" : "s")")
                    if filtered.isEmpty {
                        EmptyStateView(title: query.isEmpty ? "No curlers yet" : "No curlers found",
                                       message: query.isEmpty ? "Add teammates, spares, and people you meet on the ice." : "No curlers match \"\(query)\".",
                                       systemImage: "person.crop.circle.badge.plus",
                                       actionTitle: query.isEmpty ? "Add curler" : nil) {
                            showingNew = true
                        }
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
                .cpReadableContent()
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
    @State private var name = ""
    @State private var role = "Skip"
    @State private var club = ""
    @State private var prov = ""

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        CreateScaffold(title: "Add to roster",
                       subtitle: "Add a curler to your circle.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           store.addCurler(name: name.trimmingCharacters(in: .whitespaces),
                                           role: role,
                                           club: club.trimmingCharacters(in: .whitespaces),
                                           prov: prov.trimmingCharacters(in: .whitespaces).uppercased())
                           dismiss()
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Sam Reid")
            CPChips(label: "Role", options: ["Skip", "Third", "Second", "Lead"], selection: $role)
            CPField(label: "Club", text: $club, placeholder: "Vernon CC")
            CPField(label: "Province", text: $prov, placeholder: "BC")
        }
    }
}

private struct RosterRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let curler: Curler

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: Route.curler(curler.id)) {
                HStack(spacing: 12) {
                    AvatarView(initials: curler.initials, size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(curler.name).font(.grotesk(15, .bold)).foregroundStyle(settings.ink)
                        Text("\(curler.role.uppercased()) · \(curler.club.uppercased())")
                            .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("curlplan.roster.curler.\(curler.id)")
            Spacer()
            PillButton(title: curler.following ? "In circle" : "Add", filled: !curler.following) {
                store.toggleFollow(curler.id)
            }
            .accessibilityIdentifier("curlplan.roster.follow.\(curler.id)")
        }
        .padding(12)
        .cpCard()
    }
}
