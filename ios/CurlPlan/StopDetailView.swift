import SwiftUI

struct StopDetailView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 232
    let stopID: String

    private enum Contribution: String, Identifiable { case visit, iceRead, review; var id: String { rawValue } }
    @State private var active: Contribution? = nil
    @State private var editingReview: ReviewEntry?
    @State private var deletingReview: ReviewEntry?

    var body: some View {
        Group {
            if let stop = store.stop(stopID) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        hero(stop)
                        VStack(alignment: .leading, spacing: 14) {
                            iceRead(stop)
                            communityIceReads
                            addRow
                            gamesHere(stop)
                            yourVisits
                            reviews
                            SectionHeader(title: "People you met here")
                            people(stop)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 96)
                }
                .clipped()
                .background(settings.screen)
                .ignoresSafeArea(edges: .top)
            } else {
                settings.screen
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $active) { which in
            switch which {
            case .visit:   LogVisitSheet(stopID: stopID)
            case .iceRead: AddIceReadSheet(stopID: stopID)
            case .review:  WriteReviewSheet(stopID: stopID)
            }
        }
        .sheet(item: $editingReview) { review in
            WriteReviewSheet(stopID: stopID, editingReview: review)
        }
        .alert("Delete this review?", isPresented: Binding(
            get: { deletingReview != nil }, set: { if !$0 { deletingReview = nil } }
        )) {
            Button("Delete review", role: .destructive) {
                if let review = deletingReview { store.deleteReview(stopID, id: review.id) }
                deletingReview = nil
            }
            Button("Cancel", role: .cancel) { deletingReview = nil }
        } message: { Text("This removes your local review. This cannot be undone.") }
    }

    // MARK: Hero

    private func hero(_ stop: Stop) -> some View {
        let parts = nameParts(stop.name)
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x2F6B8F), Color(hex: 0x1F2D36)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            PebbleOverlay(opacity: settings.pebbleOpacity, tint: .white.opacity(0.3))
            HouseRing(size: 200).opacity(0.5).offset(x: 130, y: -92)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 2).offset(y: 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .clipped()
        .overlay(alignment: .topLeading) {
            CircleBackButton(onDark: true) { dismiss() }
                .padding(.leading, 18)
                .padding(.top, 54)
        }
        .overlay(alignment: .topTrailing) {
            ShareLink(item: Route.stop(stopID).url) {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Share club link")
            .padding(.trailing, 18).padding(.top, 54)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin").accessibilityHidden(true)
                    Text(cityLabel(stop))
                        .font(.mono(11, .semibold))
                        .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                (Text(parts.0 + " ") + Text(parts.1).italic())
                    .font(.serif(34))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color(hex: 0x1F2D36))
        }
    }

    // MARK: Ice read (seed) + community reads

    private func iceRead(_ stop: Stop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Ice read")
            Text("Sample club conditions and record").font(.grotesk(12)).foregroundStyle(settings.muted)
            let layout: AnyLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 9))
                : AnyLayout(HStackLayout(spacing: 9))
            layout {
                iceCell(stop.iceSpeed, "SPEED", suffix: stop.iceSpeedSec)
                iceCell(stop.iceCurl, "CURL", suffix: "ft")
                iceCell(stop.iceRec, "SAMPLE W–L", accent: true)
            }
        }
    }

    private func iceCell(_ value: String, _ label: String, suffix: String? = nil, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.serif(22)).foregroundStyle(accent ? settings.accent : settings.ink)
                if let suffix {
                    Text(suffix.hasSuffix("s") ? "\(suffix.dropLast()) sec" : suffix)
                        .font(.grotesk(13))
                        .foregroundStyle(settings.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(suffix.hasSuffix("s") ? "\(suffix.dropLast()) seconds" : suffix)
                }
            }
            Text(label).font(.mono(11, .semibold))
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
                .foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11).padding(.horizontal, 12)
        .cpCard(radius: 14)
    }

    @ViewBuilder private var communityIceReads: some View {
        let reads = store.iceReads(stopID)
        if !reads.isEmpty {
            listCard(title: "Your ice reads", count: reads.count) {
                ForEach(reads) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(r.date ?? "Date not recorded") · \(r.sheet.flatMap { $0.isEmpty ? nil : "Sheet " + $0 } ?? "Sheet not recorded")")
                            .font(.grotesk(13)).foregroundStyle(settings.muted)
                        subrow(name: "\(r.speed) · \(r.curl) ft", meta: r.note)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: Contribution add-row

    private var addRow: some View {
        let layout: AnyLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ghostButton("Log visit") { active = .visit }
            ghostButton("Ice read") { active = .iceRead }
            ghostButton("Write review") { active = .review }
        }
    }

    private func ghostButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.grotesk(12, .bold)).foregroundStyle(settings.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .frame(minHeight: 44)
                .background(settings.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(settings.ink, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: Games here

    private func gamesHere(_ stop: Stop) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sample games here").font(.grotesk(12, .semibold)).foregroundStyle(settings.ink)
                Spacer()
                Text("\(stop.games.count) GP").font(.mono(11, .semibold)).foregroundStyle(settings.muted)
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            Rectangle().fill(settings.line).frame(height: 1)

            if stop.games.isEmpty {
                HStack {
                    Text("No games logged here yet").font(.grotesk(13, .medium)).foregroundStyle(settings.muted)
                    Spacer()
                }
                .padding(.vertical, 11).padding(.horizontal, 13)
            } else {
                ForEach(Array(stop.games.enumerated()), id: \.element.id) { idx, g in
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) {
                                gameLabel(g)
                                gameResult(g)
                            }
                        } else {
                            HStack(spacing: 10) {
                                gameLabel(g)
                                Spacer()
                                gameResult(g)
                            }
                        }
                    }
                    .padding(.vertical, 10).padding(.horizontal, 13)
                    if idx < stop.games.count - 1 { Rectangle().fill(settings.line).frame(height: 1) }
                }
            }
        }
        .cpCard()
    }

    private func gameLabel(_ game: GameLine) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(game.res == "W" ? settings.accent : settings.muted)
                .opacity(game.res == "W" ? 1 : 0.7)
                .frame(width: 7, height: 7)
            Text(game.label).font(.grotesk(13, .semibold)).foregroundStyle(settings.ink)
        }
    }

    private func gameResult(_ game: GameLine) -> some View {
        HStack(spacing: 10) {
            Text(game.score).font(.serif(16)).foregroundStyle(settings.ink)
            ResultBadge(res: game.res)
        }
    }

    @ViewBuilder private var yourVisits: some View {
        let visits = store.visits(stopID)
        if !visits.isEmpty {
            listCard(title: "Your visits", count: visits.count) {
                ForEach(visits) { v in subrow(name: v.date, meta: v.note) }
            }
        }
    }

    @ViewBuilder private var reviews: some View {
        let list = store.reviews(stopID)
        if !list.isEmpty {
            listCard(title: "Your local reviews", count: list.count) {
                ForEach(list) { r in
                    HStack(spacing: 9) {
                        StarsRow(count: r.stars)
                        Spacer()
                        if !r.note.isEmpty {
                            Text(r.note).font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                .multilineTextAlignment(.trailing).frame(maxWidth: 180, alignment: .trailing)
                        }
                        Menu {
                            Button("Edit review") { editingReview = r }
                            Button("Delete review", role: .destructive) { deletingReview = r }
                        } label: {
                            Image(systemName: "ellipsis").foregroundStyle(settings.ink)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("Review actions")
                        .accessibilityIdentifier("curlplan.review.actions.\(r.id)")
                    }
                    .padding(.vertical, 9).padding(.horizontal, 13)
                }
            }
        }
    }

    // MARK: People met

    private func people(_ stop: Stop) -> some View {
        VStack(spacing: 12) {
            if stop.met.isEmpty {
                HStack {
                    Text("No connections logged here yet.").font(.mono(11, .medium)).foregroundStyle(settings.muted)
                    Spacer()
                }
            }
            ForEach(stop.met, id: \.self) { id in
                if let c = store.curler(id) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 10) {
                                personLink(c)
                                personFollowButton(c)
                            }
                        } else {
                            HStack(spacing: 11) {
                                personLink(c)
                                Spacer()
                                personFollowButton(c)
                            }
                        }
                    }
                }
            }
        }
    }

    private func personLink(_ curler: Curler) -> some View {
        NavigationLink(value: Route.curler(curler.id)) {
            HStack(spacing: 11) {
                AvatarView(initials: curler.initials, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(curler.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                    Text("\(curler.role.uppercased()) · \(curler.club.uppercased())")
                        .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func personFollowButton(_ curler: Curler) -> some View {
        PillButton(title: store.isFollowing(curler.id) ? "Following" : "Follow",
                   filled: !store.isFollowing(curler.id)) {
            store.toggleFollow(curler.id)
        }
    }

    // MARK: Shared list-card + row helpers

    private func listCard<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.grotesk(12, .semibold)).foregroundStyle(settings.ink)
                Spacer()
                Text("\(count)").font(.mono(10, .medium)).foregroundStyle(settings.muted)
            }
            .padding(.vertical, 11).padding(.horizontal, 13)
            Rectangle().fill(settings.line).frame(height: 1)
            content()
        }
        .cpCard()
    }

    private func subrow(name: String, meta: String) -> some View {
        HStack(spacing: 9) {
            Text(name).font(.grotesk(13, .semibold)).foregroundStyle(settings.ink)
            Spacer()
            if !meta.isEmpty {
                Text(meta).font(.mono(10, .medium)).foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 170, alignment: .trailing)
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 13)
    }

    // MARK: Helpers

    private func nameParts(_ s: String) -> (String, String) {
        let parts = s.split(separator: " ").map(String.init)
        guard let first = parts.first else { return (s, "") }
        let rest = parts.dropFirst().joined(separator: " ")
        return (first, rest.isEmpty ? "Curling Club" : rest)
    }

    private func cityLabel(_ stop: Stop) -> String {
        let city = stop.club.uppercased().split(separator: " ").first.map(String.init) ?? stop.prov
        return "\(city), \(stop.prov) · \(stop.dates)"
    }
}

// MARK: - Contribution sheets

private struct LogVisitSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stopID: String

    @State private var draft = ContributionDraft()

    var body: some View {
        CreateScaffold(title: "Log a visit", subtitle: "Close keeps your draft on this device.",
                       canSave: !draft.visitDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, onCancel: { dismiss() },
                       onSave: { store.addVisit(stopID, date: draft.visitDate, note: draft.note); dismiss() }, cancelTitle: "Close") {
            CPField(label: "Date", text: $draft.visitDate, placeholder: "Today")
            CPTextArea(label: "Note (optional)", text: $draft.note, placeholder: "Draw weight was up, great hosts…")
        }
        .modifier(ContributionDraftRecovery(stopID: stopID, kind: "visit", draft: $draft))
    }
}

private struct AddIceReadSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stopID: String

    private var recordedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: draft.date)
    }

    private var canSave: Bool { !draft.curl.trimmingCharacters(in: .whitespaces).isEmpty }

    @State private var draft = ContributionDraft()

    var body: some View {
        CreateScaffold(title: "Add an ice read", subtitle: "Close keeps your draft on this device.",
                       canSave: canSave, onCancel: { dismiss() },
                       onSave: { store.addIceRead(stopID, speed: draft.speed, curl: draft.curl.trimmingCharacters(in: .whitespaces), note: draft.note, date: recordedDate, sheet: draft.sheet); dismiss() }, cancelTitle: "Close") {
            DatePicker("Date", selection: $draft.date, displayedComponents: .date)
            CPField(label: "Sheet (optional)", text: $draft.sheet, placeholder: "e.g. 3 or A")
            CPChips(label: "Speed", options: ["Keen", "Fast", "Medium", "Slow"], selection: $draft.speed)
            CPField(label: "Curl (ft)", text: $draft.curl, placeholder: "4–5")
            CPTextArea(label: "Note (optional)", text: $draft.note, placeholder: "Straight early, more curl after the hog…")
        }
        .modifier(ContributionDraftRecovery(stopID: stopID, kind: "ice", draft: $draft))
    }
}

private struct WriteReviewSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stopID: String
    var editingReview: ReviewEntry? = nil
    @State private var draft = ReviewDraft()
    @State private var loaded = false
    @State private var confirmingDiscard = false
    @State private var saveFailed = false

    var body: some View {
        CreateScaffold(title: editingReview == nil ? "Write a review" : "Edit review",
                       subtitle: "Saved on this device. Close keeps your draft.",
                       canSave: (1...5).contains(draft.stars), onCancel: { dismiss() },
                       onSave: {
                           if store.saveReview(stopID, draft: draft, editingID: editingReview?.id) { dismiss() }
                           else { saveFailed = true }
                       }, cancelTitle: "Close") {
            VStack(alignment: .leading, spacing: 6) {
                Text("RATING").font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
                StarPicker(rating: $draft.stars)
            }
            CPTextArea(label: "Review", text: $draft.note, placeholder: "Great ice, friendly club, fast bar service.")
            Button("Discard draft", role: .destructive) { confirmingDiscard = true }
        }
        .onAppear {
            guard !loaded else { return }
            draft = store.state.reviewDrafts[store.reviewDraftKey(stopID, editingID: editingReview?.id)]
                ?? editingReview.map { ReviewDraft(stars: $0.stars, note: $0.note) } ?? ReviewDraft()
            loaded = true
        }
        .onChange(of: draft) { _, value in
            if loaded { store.saveReviewDraft(stopID, draft: value, editingID: editingReview?.id) }
        }
        .confirmationDialog("Discard this draft?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) {
                store.discardReviewDraft(stopID, editingID: editingReview?.id)
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: { Text("Your published review stays unchanged.") }
        .alert("Could not save review", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: { Text("The review may no longer exist. Your changes have not been published.") }
    }
}

private struct ContributionDraftRecovery: ViewModifier {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stopID: String
    let kind: String
    @Binding var draft: ContributionDraft
    @State private var loaded = false
    @State private var discard = false

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            Button("Discard draft", role: .destructive) { discard = true }
                .frame(minHeight: 44)
        }
        .onAppear {
            guard !loaded else { return }
            if let saved = store.state.contributionDrafts?[store.contributionDraftKey(stopID, kind: kind)] { draft = saved }
            loaded = true
        }
        .onChange(of: draft) { _, value in
            if loaded { store.saveContributionDraft(stopID, kind: kind, draft: value) }
        }
        .alert("Discard this draft?", isPresented: $discard) {
            Button("Discard draft", role: .destructive) {
                store.discardContributionDraft(stopID, kind: kind); dismiss()
            }
            Button("Keep draft", role: .cancel) {}
        } message: { Text("Saved visits and ice readings stay unchanged.") }
    }
}
