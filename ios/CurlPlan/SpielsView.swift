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
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add event")
                .accessibilityIdentifier("curlplan.event.add")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your season ahead")
                    if let next = store.upcomingEvents().first {
                        SectionHeader(title: "Next event")
                        Text(next.name + " · " + next.scheduleLabel + " · " + next.whereText)
                            .font(.grotesk(15, .semibold)).foregroundStyle(settings.ink)
                    }
                    SectionHeader(title: "Upcoming and in progress")
                    ForEach(store.upcomingEvents()) { SpielRow(spiel: $0) }
                    SectionHeader(title: "Past or not going")
                    ForEach(store.state.addedSpiels.filter { $0.startAt != nil && (($0.endAt ?? 0) < Store.now() || store.spielStatus($0.id) == "Not going") }.sorted { ($0.startAt ?? 0) > ($1.startAt ?? 0) }) { SpielRow(spiel: $0) }
                    SectionHeader(title: "Undated events and samples")
                    ForEach(store.spiels.filter { $0.startAt == nil }) { SpielRow(spiel: $0) }
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
    var existing: Spiel? = nil
    @State private var draft = EventDraft()
    @State private var confirmingDiscard = false
    @State private var loaded = false
    @State private var failed = false
    private var zone: String { draft.timeZone }
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.end > draft.start
    }

    var body: some View {
        CreateScaffold(title: existing == nil ? "New event" : "Edit event",
                       subtitle: "Close keeps your draft on this device. Going is intent, not registration.",
                       canSave: canSave, onCancel: { dismiss() }, onSave: {
            if store.saveScheduledEvent(id: existing?.id, name: draft.name, location: draft.location,
                                        start: draft.start.timeIntervalSince1970, end: draft.end.timeIntervalSince1970,
                                        timeZone: zone, kind: draft.kind, preparation: draft.preparation, status: draft.status, planning: draft.planning) { dismiss() }
            else { failed = true }
        }, cancelTitle: "Close") {
            Button("Discard draft", role: .destructive) { confirmingDiscard = true }
                .frame(minHeight: 44)
            CPField(label: "Name", text: $draft.name, placeholder: "League game")
            CPField(label: "Location", text: $draft.location, placeholder: "Club and sheet")
            Picker("Event type", selection: $draft.kind) {
                ForEach(["League game", "Practice", "Bonspiel", "Event"], id: \.self) { Text($0) }
            }
            DatePicker("Starts", selection: Binding(get: { draft.start }, set: { value in
                let duration = draft.end.timeIntervalSince(draft.start); draft.start = value; draft.end = value.addingTimeInterval(duration)
            }))
            DatePicker("Ends", selection: $draft.end, in: draft.start...)
            Text("Time zone: " + zone).font(.footnote)
            CPTextArea(label: "Preparation", text: $draft.preparation, placeholder: "Arrival time, equipment, or focus")
            DisclosureGroup("Event details and trip planning") {
                Text("Your planning notes. Confirm details with the organizer.").font(.footnote)
                ForEach(EventPlanning.fields, id: \.0) { field in
                    CPTextArea(label: field.0, text: Binding(get: {
                        (draft.planning ?? EventPlanning())[keyPath: field.1]
                    }, set: { value in
                        var planning = draft.planning ?? EventPlanning()
                        planning[keyPath: field.1] = value; draft.planning = planning
                    }), placeholder: "Not recorded")
                }
            }
            CPChips(label: "Local attendance intent", options: ["Going", "Considering", "Not going"], selection: $draft.status)
            let conflicts = store.eventConflicts(start: draft.start.timeIntervalSince1970, end: draft.end.timeIntervalSince1970, excluding: existing?.id)
            if !conflicts.isEmpty {
                Text("Overlaps with: " + conflicts.map(\.name).joined(separator: ", "))
                    .font(.body).accessibilityIdentifier("curlplan.event.conflicts")
            }
        }
        .environment(\.timeZone, TimeZone(identifier: zone) ?? .current)
        .onAppear {
            guard !loaded else { return }
            if let existing {
                draft.name = existing.name; draft.location = existing.whereText
                draft.start = Date(timeIntervalSince1970: existing.startAt ?? Store.now())
                draft.end = Date(timeIntervalSince1970: existing.endAt ?? draft.start.timeIntervalSince1970 + 7200)
                draft.kind = existing.eventKind ?? "Event"; draft.preparation = existing.preparation ?? ""
                draft.planning = existing.planning
                let saved = store.spielStatus(existing.id)
                draft.status = ["Going", "Considering", "Not going"].contains(saved) ? saved : "Considering"
            }
            if let saved = store.state.eventDrafts?[existing?.id ?? "new"] { draft = saved }
            else if let zone = existing?.timeZoneID { draft.timeZone = zone }
            loaded = true
        }
        .onChange(of: draft) { _, value in
            if loaded { store.saveEventDraft(value, editingID: existing?.id) }
        }
        .alert("Discard this event draft?", isPresented: $confirmingDiscard) {
            Button("Discard draft", role: .destructive) {
                store.discardEventDraft(editingID: existing?.id); dismiss()
            }
            .accessibilityIdentifier("curlplan.event.discard.confirm")
            Button("Keep draft", role: .cancel) {}
        } message: { Text("Any saved event stays unchanged.") }
        .alert("Could not save event", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }
}

private struct SpielRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingDetail = false
    let spiel: Spiel

    var body: some View {
        let status = store.spielStatus(spiel.id)
        let solid = status == "Going"
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    spielIdentity
                    statusBadge(status, solid: solid)
                }
            } else {
                HStack(alignment: .top) {
                    spielIdentity
                    Spacer()
                    statusBadge(status, solid: solid)
                }
            }

            if let start = spiel.startAt, let end = spiel.endAt, status != "Not going" {
                let conflicts = store.eventConflicts(start: start, end: end, excluding: spiel.id)
                if !conflicts.isEmpty {
                    Text("Overlaps with: " + conflicts.map(\.name).joined(separator: ", "))
                        .font(.grotesk(14, .semibold)).foregroundStyle(settings.ink)
                }
            }
            let attendeeLayout: AnyLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 11))
            attendeeLayout {
                AvatarStack(
                    initials: spiel.going.map { store.curler($0)?.initials ?? "?" },
                    accessibilityNames: spiel.going.compactMap { store.curler($0)?.name },
                    size: 28
                )
                Text("\(spiel.going.count) of your circle going")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                PillButton(title: "Details", filled: false) { showingDetail = true }
                    .accessibilityIdentifier("curlplan.event.details.\(spiel.id)")
            }
        }
        .padding(14)
        .cpCard()
        .sheet(isPresented: $showingDetail) { SpielDetailSheet(spielID: spiel.id) }
    }

    private var spielIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(spiel.scheduleLabel)
                .font(.mono(11, .semibold))
                .tracking(0)
                .foregroundStyle(settings.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(spiel.name)
                .font(.serif(21))
                .foregroundStyle(settings.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(spiel.whereText)
                .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .layoutPriority(1)
    }

    private func statusBadge(_ status: String, solid: Bool) -> some View {
        Text(status)
            .font(solid ? .mono(11, .bold) : .grotesk(11, .semibold))
            .tracking(solid && !dynamicTypeSize.isAccessibilitySize ? 1 : 0)
            .foregroundStyle(solid ? settings.onAccent : settings.muted)
            .padding(.vertical, solid ? 4 : 5)
            .padding(.horizontal, solid ? 8 : 10)
            .background(solid ? settings.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous)
                    .strokeBorder(solid ? Color.clear : settings.line, lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: true)
    }
}

struct SpielDetailSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let spielID: String

    @State private var editing = false
    @State private var deleting = false
    private var owned: Bool { store.state.addedSpiels.contains { $0.id == spielID } }
    private var statuses: [String] { ["Going", "Considering", "Not going"] }

    var body: some View {
        Group {
            if let spiel = store.spiels.first(where: { $0.id == spielID }) {
                ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Capsule().fill(settings.line).frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 16)

                    Text(spiel.scheduleLabel)
                        .font(.mono(11, .semibold))
                        .tracking(0)
                        .foregroundStyle(settings.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(spiel.name).font(.serif(26)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted)
                        .padding(.top, 2).padding(.bottom, 20)

                    if owned {
                        Text(spiel.eventKind ?? "Event").font(.headline)
                        Text(spiel.preparation?.isEmpty == false ? spiel.preparation! : "No preparation notes yet.")
                            .font(.body).padding(.vertical, 8)
                        HStack {
                            Button("Edit event") { editing = true }.frame(minHeight: 44)
                            Button("Delete event", role: .destructive) { deleting = true }.frame(minHeight: 44)
                        }
                    }
                    if let start = spiel.startAt, let end = spiel.endAt, store.spielStatus(spiel.id) != "Not going" {
                        let conflicts = store.eventConflicts(start: start, end: end, excluding: spiel.id)
                        if !conflicts.isEmpty { Text("Overlaps with: " + conflicts.map(\.name).joined(separator: ", ")).font(.body) }
                    }
                    Text("Event details and trip planning").font(.headline)
                    Text("Personal notes; confirm details with the organizer.").font(.footnote)
                    ForEach(EventPlanning.fields, id: \.0) { field in
                        let value = (spiel.planning ?? EventPlanning())[keyPath: field.1]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.0).font(.subheadline.bold())
                            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded" : value)
                                .font(.body).textSelection(.enabled)
                        }.padding(.vertical, 5)
                    }
                    let results = store.state.posts.filter { $0.kind == .result && $0.eventID == spiel.id }
                    if !results.isEmpty {
                        Text("Recorded results").font(.headline)
                        ForEach(results) { result in
                            Text("\(result.scoreFor ?? 0)–\(result.scoreAgainst ?? 0) \(result.vs ?? "") · \(result.body ?? "")")
                                .font(.body).padding(.vertical, 4)
                        }
                    }
                    Text("Saved on this device only; this does not register you with the organizer.").font(.footnote).padding(.vertical, 8)
                    Text("LOCAL ATTENDANCE INTENT").font(.mono(10, .medium)).tracking(1.5)
                        .foregroundStyle(settings.muted).padding(.bottom, 8)
                    HStack(spacing: 8) {
                        ForEach(statuses, id: \.self) { opt in
                            let on = store.spielStatus(spiel.id) == opt
                            Button { store.setSpielStatus(spiel.id, opt) } label: {
                                Text(opt).font(.grotesk(12, .semibold))
                                    .foregroundStyle(on ? settings.onAccent : settings.ink)
                                    .padding(.vertical, 9).padding(.horizontal, 14)
                                    .background(on ? settings.accent : settings.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("curlplan.attendance.\(opt)")
                            .accessibilityValue(on ? "Selected" : "Not selected")
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
                        Text("Done").font(.grotesk(14, .bold)).foregroundStyle(settings.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(settings.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
                .sheet(isPresented: $editing) { NewSpielSheet(existing: spiel) }
                .alert("Delete this event?", isPresented: $deleting) {
                    Button("Delete event", role: .destructive) { if store.deleteScheduledEvent(spielID) { dismiss() } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("This removes only your saved event on this device.") }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(settings.card)
            } else {
                settings.card
            }
        }
    }
}
