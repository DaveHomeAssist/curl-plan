import SwiftUI

// Segmented composer for the Locker Room feed: Note / Result / Review.
// Parity with the web openCompose() sheet.
struct ComposeSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let editingPostID: String?
    private typealias Kind = PostDraft.Kind
    @State private var draft = PostDraft()
    @State private var loaded = false
    @State private var confirmingDiscard = false
    @State private var saveFailed = false

    init(editingPostID: String? = nil) { self.editingPostID = editingPostID }
    private var canSave: Bool { draft.isValid }

    private func practiceBinding(_ key: WritableKeyPath<PracticeLog, String>) -> Binding<String> {
        Binding(get: { (draft.practice ?? PracticeLog())[keyPath: key] }, set: { value in
            var practice = draft.practice ?? PracticeLog(); practice[keyPath: key] = value; draft.practice = practice
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 14)

            Text(editingPostID == nil ? "Share" : "Edit post").font(.serif(24)).foregroundStyle(settings.ink)
            Text("Drafts and posts are saved on this device. Close keeps your draft.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 16)

            // type segment
            if editingPostID == nil {
                HStack(spacing: 6) {
                    ForEach(Kind.allCases, id: \.self) { k in
                        let on = draft.kind == k
                        Button { draft.kind = k } label: {
                            Text(k.rawValue)
                                .font(.grotesk(12, .semibold))
                                .foregroundStyle(on ? settings.onAccent : settings.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(on ? settings.accent : settings.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 16)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    switch draft.kind {
                    case .practice:
                        CPField(label: "Practice date (YYYY-MM-DD)", text: practiceBinding(\.date), placeholder: "2026-09-27")
                        CPField(label: "Duration (minutes)", text: practiceBinding(\.minutes), placeholder: "60", keyboard: .numberPad)
                        CPTextArea(label: "Drills", text: practiceBinding(\.drills), placeholder: "What did you practise?")
                        CPTextArea(label: "Focus", text: practiceBinding(\.focus), placeholder: "What were you working on?")
                        CPTextArea(label: "Observations", text: practiceBinding(\.observations), placeholder: "What will you carry into your next game?")
                    case .note:
                        CPTextArea(label: "What's the word?", text: $draft.body,
                                   placeholder: "Share a thought with your circle…")
                    case .result:
                        Picker("Scheduled event", selection: Binding(get: { draft.eventID ?? "" }, set: { draft.eventID = $0.isEmpty ? nil : $0 })) {
                            Text("No linked event").tag("")
                            ForEach(store.state.addedSpiels) { event in
                                Text(event.name + " · " + event.scheduleLabel).tag(event.id)
                            }
                            if let id = draft.eventID, !store.state.addedSpiels.contains(where: { $0.id == id }) {
                                Text("Previously linked event (removed)").tag(id)
                            }
                        }
                        .accessibilityIdentifier("curlplan.result.event")
                        HStack(spacing: 12) {
                            CPField(label: "For", text: $draft.scoreFor, placeholder: "8", keyboard: .numberPad)
                            CPField(label: "Against", text: $draft.scoreAgainst, placeholder: "5", keyboard: .numberPad)
                        }
                        CPField(label: "Opponent", text: $draft.opponent, placeholder: "Northern")
                        CPTextArea(label: "Note (optional)", text: $draft.body, placeholder: "How did it go?")
                    case .review:
                        ClubField(text: $draft.club)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RATING").font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
                            StarPicker(rating: $draft.stars)
                        }
                        CPTextArea(label: "Note", text: $draft.note, placeholder: "fast, 5–6 ft of curl")
                    }
                }
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Close").font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                Button { save() } label: {
                    Text(editingPostID == nil ? "Post" : "Save changes").font(.grotesk(14, .bold)).foregroundStyle(settings.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(canSave ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.top, 14)
            Button("Discard draft", role: .destructive) { confirmingDiscard = true }
                .padding(.top, 12)
                .accessibilityIdentifier("curlplan.compose.discard")
        }
        .padding(.horizontal, 22).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
        .onAppear {
            guard !loaded else { return }
            let saved = store.state.postDrafts[editingPostID ?? "new"]
            let post = editingPostID.flatMap { id in store.state.posts.first { $0.id == id } }
            draft = saved ?? post.map(PostDraft.init(post:)) ?? PostDraft()
            loaded = true
        }
        .onChange(of: draft) { _, value in
            if loaded { store.savePostDraft(value, editingID: editingPostID) }
        }
        .confirmationDialog("Discard this draft?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) {
                store.discardPostDraft(editingID: editingPostID)
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("This removes only the draft. Any published post stays unchanged.")
        }
        .alert("Could not save post", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The post may no longer exist. Your draft has not been published.")
        }
    }

    private func save() {
        guard store.savePost(draft, editingID: editingPostID) else {
            saveFailed = true
            return
        }
        dismiss()
    }

}

// Club text field with autocomplete suggestions from the shared CLUB list.
struct ClubField: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var text: String

    private var suggestions: [String] {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        return Clubs.all.filter { $0.localizedCaseInsensitiveContains(q) }.prefix(4).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CPField(label: "Club", text: $text, placeholder: "Granite City CC")
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { text = String(s.split(separator: "·").first ?? "").trimmingCharacters(in: .whitespaces) } label: {
                            HStack {
                                Text(s).font(.grotesk(12)).foregroundStyle(settings.ink)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}
