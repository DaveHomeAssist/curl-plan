import SwiftUI

// Segmented composer for the Locker Room feed: Note / Result / Review.
// Parity with the web openCompose() sheet.
struct ComposeSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private enum Kind: String, CaseIterable { case note = "Note", result = "Result", review = "Review" }
    @State private var kind: Kind = .note

    // shared
    @State private var body_ = ""
    // result
    @State private var opponent = ""
    @State private var forScore = ""
    @State private var againstScore = ""
    // review
    @State private var club = ""
    @State private var stars = 5
    @State private var note = ""

    private var canSave: Bool {
        switch kind {
        case .note:   return !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .result: return Int(forScore.trimmingCharacters(in: .whitespaces)) != nil
                          && Int(againstScore.trimmingCharacters(in: .whitespaces)) != nil
        case .review: return !club.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 14)

            Text("Share").font(.serif(24)).foregroundStyle(settings.ink)
            Text("Posts to your Locker Room — saved on this device.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 16)

            // type segment
            HStack(spacing: 6) {
                ForEach(Kind.allCases, id: \.self) { k in
                    let on = kind == k
                    Button { kind = k } label: {
                        Text(k.rawValue)
                            .font(.grotesk(12, .semibold))
                            .foregroundStyle(on ? .white : settings.ink)
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    switch kind {
                    case .note:
                        CPTextArea(label: "What's the word?", text: $body_,
                                   placeholder: "Share a thought with your circle…")
                    case .result:
                        HStack(spacing: 12) {
                            CPField(label: "For", text: $forScore, placeholder: "8", keyboard: .numberPad)
                            CPField(label: "Against", text: $againstScore, placeholder: "5", keyboard: .numberPad)
                        }
                        CPField(label: "Opponent", text: $opponent, placeholder: "Northern")
                        CPTextArea(label: "Note (optional)", text: $body_, placeholder: "How did it go?")
                    case .review:
                        ClubField(text: $club)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("RATING").font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
                            StarPicker(rating: $stars)
                        }
                        CPTextArea(label: "Note", text: $note, placeholder: "fast, 5–6 ft of curl")
                    }
                }
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel").font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                Button { save() } label: {
                    Text("Post").font(.grotesk(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(canSave ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 22).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    private func save() {
        guard canSave else { return }
        switch kind {
        case .note:
            store.addNote(body: body_.trimmingCharacters(in: .whitespacesAndNewlines))
        case .result:
            store.addResult(body: body_.trimmingCharacters(in: .whitespacesAndNewlines),
                            scoreFor: Int(forScore) ?? 0, scoreAgainst: Int(againstScore) ?? 0,
                            vs: opponent.trimmingCharacters(in: .whitespaces))
        case .review:
            store.addReview(club: club.trimmingCharacters(in: .whitespaces),
                            stars: stars, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
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
