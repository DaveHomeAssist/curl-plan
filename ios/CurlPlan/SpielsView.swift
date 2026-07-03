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
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your season ahead")
                    ForEach(store.spiels) { sp in
                        SpielRow(spiel: sp)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
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
    @State private var name = ""
    @State private var location = ""
    @State private var dates = ""
    @State private var status = "You're in"

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        CreateScaffold(title: "New spiel",
                       subtitle: "Add a bonspiel to your season ahead.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           store.addSpiel(name: name.trimmingCharacters(in: .whitespaces),
                                          whereText: location.trimmingCharacters(in: .whitespaces),
                                          whenText: dates.trimmingCharacters(in: .whitespaces).uppercased(),
                                          status: status)
                           dismiss()
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Brier Patch Open")
            CPField(label: "Location", text: $location, placeholder: "Kamloops, BC")
            CPField(label: "Dates", text: $dates, placeholder: "FEB 14–16")
            CPChips(label: "Your status", options: ["You're in", "Watching", "Invite"], selection: $status)
        }
    }
}

private struct SpielRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingDetail = false
    let spiel: Spiel

    var body: some View {
        let solid = spiel.status == "You're in"
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                    Text(spiel.name).font(.serif(21)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted).padding(.top, 2)
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
                AvatarStack(initials: spiel.going.map { store.curler($0)?.initials ?? "?" }, size: 28)
                Text("\(spiel.going.count) of your circle going")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                PillButton(title: "Details", filled: false) { showingDetail = true }
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

                    Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                    Text(spiel.name).font(.serif(26)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted)
                        .padding(.top, 2).padding(.bottom, 20)

                    Text("YOUR STATUS").font(.mono(10, .medium)).tracking(1.5)
                        .foregroundStyle(settings.muted).padding(.bottom, 8)
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
                    .padding(.bottom, 22)

                    Text("\(spiel.going.count) OF YOUR CIRCLE GOING").font(.mono(10, .medium))
                        .tracking(1.5).foregroundStyle(settings.muted).padding(.bottom, 10)
                    if spiel.going.isEmpty {
                        Text("No one from your circle has joined yet.")
                            .font(.grotesk(13)).foregroundStyle(settings.muted)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(spiel.going, id: \.self) { id in
                                if let c = store.curler(id) {
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

                    Spacer(minLength: 18)
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
