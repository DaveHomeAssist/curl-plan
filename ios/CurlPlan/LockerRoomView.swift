import SwiftUI

struct LockerRoomView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNew = false
    @State private var searching = false
    @State private var query = ""
    @State private var mode: LockerMode = .following
    @State private var actionMessage: String?
    @State private var undoToken: UndoToken?

    private var filteredFeed: [FeedItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let source = store.lockerFollowingFeed
        guard !q.isEmpty else { return source }
        return source.filter { feedMatches($0, q) }
    }

    private var discoverSuggestions: [Curler] {
        store.discoverSuggestions
    }

    private func feedMatches(_ item: FeedItem, _ q: String) -> Bool {
        switch item {
        case .result(let p):
            return (store.curler(p.author)?.name ?? "").localizedCaseInsensitiveContains(q)
                || p.body.localizedCaseInsensitiveContains(q)
                || p.vs.localizedCaseInsensitiveContains(q)
        case .spiel(let p):
            return p.spielName.localizedCaseInsensitiveContains(q)
                || p.title.localizedCaseInsensitiveContains(q)
                || p.whereText.localizedCaseInsensitiveContains(q)
        case .review(let p):
            return (store.curler(p.author)?.name ?? "").localizedCaseInsensitiveContains(q)
                || p.rink.localizedCaseInsensitiveContains(q)
                || p.note.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(settings.muted)
                    TextField("Search the feed", text: $query)
                        .font(.grotesk(15)).foregroundStyle(settings.ink).tint(settings.accent)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("curlplan.locker.searchField")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(settings.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("curlplan.locker.clearSearch")
                    }
                }
                .padding(.vertical, 9).padding(.horizontal, 13)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .cpReadableContent()
            }
            if let actionMessage {
                HStack(spacing: 10) {
                    Text(actionMessage)
                        .font(.mono(10, .medium))
                        .foregroundStyle(settings.muted)
                    Spacer()
                    if let undoToken {
                        Button("Undo") {
                            if let receipt = store.undo(undoToken) {
                                handleReceipt(receipt)
                            }
                        }
                        .font(.grotesk(12, .bold))
                        .foregroundStyle(settings.accent)
                        .accessibilityIdentifier("curlplan.action.undo")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .cpReadableContent()
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    switch mode {
                    case .following:
                        if filteredFeed.isEmpty {
                            EmptyStateView(title: query.isEmpty ? "No locker room posts yet" : "No posts found",
                                           message: query.isEmpty ? "Log a result to start your season feed." : "No posts match \"\(query)\".",
                                           systemImage: "bubble.left.and.bubble.right")
                        }
                        ForEach(filteredFeed) { item in
                            FeedCard(item: item, onReceipt: handleReceipt)
                        }
                    case .discover:
                        if discoverSuggestions.isEmpty {
                            EmptyStateView(title: "No local suggestions",
                                           message: "Every locally referenced curler is already saved to your roster.",
                                           systemImage: "person.2")
                        } else {
                            ForEach(discoverSuggestions) { curler in
                                DiscoverCurlerCard(curler: curler)
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
        .overlay(alignment: .bottom) {
            Button { showingNew = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(settings.accent)
                    .clipShape(Circle())
                    .shadow(color: settings.accent.opacity(0.6), radius: 14, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log result")
            .accessibilityIdentifier("curlplan.logResult")
            .padding(.trailing, 18)
            .padding(.bottom, 104)
            .cpReadableContent(alignment: .trailing)
        }
        .sheet(isPresented: $showingNew) { NewResultSheet(onReceipt: handleReceipt) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Locker Room").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
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
                .accessibilityLabel(searching ? "Close locker search" : "Search locker")
                .accessibilityIdentifier("curlplan.locker.search")
            }
            HStack(spacing: 22) {
                lockerTab(.following, "Local feed", identifier: "following")
                lockerTab(.discover, "Suggested", identifier: "discover")
                Spacer()
            }
            .overlay(alignment: .bottom) { settings.line.frame(height: 1) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .cpReadableContent()
    }

    private func handleReceipt(_ receipt: MutationReceipt) {
        actionMessage = receipt.userMessage
        undoToken = receipt.undoToken
    }

    private func lockerTab(_ tab: LockerMode, _ title: String, identifier: String) -> some View {
        Button {
            mode = tab
            query = ""
        } label: {
            VStack(spacing: 9) {
                Text(title)
                    .font(.grotesk(14, mode == tab ? .bold : .medium))
                    .foregroundStyle(mode == tab ? settings.ink : settings.muted)
                (mode == tab ? settings.accent : Color.clear).frame(height: 2.5)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(title)")
        .accessibilityIdentifier("curlplan.locker.tab.\(identifier)")
    }
}

private enum LockerMode {
    case following
    case discover
}

struct FeedCard: View {
    @EnvironmentObject var store: Store
    let item: FeedItem
    let onReceipt: (MutationReceipt) -> Void
    var body: some View {
        Group {
            switch item {
            case .result(let p): ResultCard(post: p, onReceipt: onReceipt)
            case .spiel(let p): SpielCard(post: p)
            case .review(let p): ReviewCard(post: p)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onReceipt(store.deleteFeedItem(item.id))
            } label: {
                Label("Delete post", systemImage: "trash")
            }
        }
    }
}

private struct DiscoverCurlerCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let curler: Curler

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: Route.curler(curler.id)) {
                HStack(spacing: 12) {
                    AvatarView(initials: curler.initials, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(curler.name)
                            .font(.grotesk(15, .bold))
                            .foregroundStyle(settings.ink)
                        Text("\(curler.role.uppercased()) · \(curler.club.uppercased())")
                            .font(.mono(10, .medium))
                            .foregroundStyle(settings.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            PillButton(title: "Save") {
                store.toggleFollow(curler.id)
            }
            .accessibilityIdentifier("curlplan.discover.follow.\(curler.id)")
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

private struct ResultCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: ResultPost
    let onReceipt: (MutationReceipt) -> Void
    @State private var showingEdit = false

    private func resultHeader(initials: String, name: String, sub: String) -> some View {
        HStack(spacing: 10) {
            AvatarView(initials: initials, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                Text(sub).font(.mono(11, .medium)).foregroundStyle(settings.muted)
            }
            Spacer()
            Image(systemName: "ellipsis").foregroundStyle(settings.muted)
        }
    }

    var body: some View {
        let author = store.curler(post.author)
        let name = author?.name ?? store.me.name
        let initials = author?.initials ?? store.me.initials
        let sub = (author.map { "\($0.role.uppercased()) · \($0.club.uppercased())" } ?? "YOU") + " · \(post.time)"
        VStack(alignment: .leading, spacing: 11) {
            if let author {
                NavigationLink(value: Route.curler(author.id)) {
                    resultHeader(initials: initials, name: name, sub: sub)
                }
                .buttonStyle(.plain)
            } else {
                resultHeader(initials: initials, name: name, sub: sub)
            }

            Text(post.body).font(.grotesk(15)).foregroundStyle(settings.ink).lineSpacing(2)

            HStack(spacing: 11) {
                (Text("\(post.scoreFor)").foregroundColor(settings.ink)
                    + Text(" – ").foregroundColor(settings.muted)
                    + Text("\(post.scoreAgainst)").foregroundColor(settings.ink))
                    .font(.serif(28))
                Text(post.res)
                    .font(.mono(9, .bold)).tracking(1).foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(settings.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Spacer()
                Text(post.vs).font(.mono(11, .medium)).foregroundStyle(settings.muted)
            }
            .padding(.vertical, 10).padding(.horizontal, 13)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("LOCAL RESULT")
                .font(.mono(9, .medium))
                .tracking(1.4)
                .foregroundStyle(settings.muted)

            if store.gameResult(post.id) != nil {
                HStack(spacing: 8) {
                    Button("Edit") { showingEdit = true }
                        .font(.grotesk(12, .bold))
                        .foregroundStyle(settings.ink)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(settings.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("curlplan.result.edit")
                    Button("Delete") {
                        onReceipt(store.deleteResult(post.id))
                    }
                    .font(.grotesk(12, .bold))
                    .foregroundStyle(settings.houseRed)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("curlplan.result.delete")
                }
            }
        }
        .padding(14)
        .cpCard(radius: 18)
        .sheet(isPresented: $showingEdit) {
            EditResultSheet(post: post, onReceipt: onReceipt)
        }
    }
}

private struct EditResultSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let post: ResultPost
    let onReceipt: (MutationReceipt) -> Void
    @State private var opponent: String
    @State private var forScore: String
    @State private var againstScore: String
    @State private var note: String

    init(post: ResultPost, onReceipt: @escaping (MutationReceipt) -> Void) {
        self.post = post
        self.onReceipt = onReceipt
        let opponent = post.vs.replacingOccurrences(of: "^vs\\s+", with: "", options: [.regularExpression, .caseInsensitive])
        _opponent = State(initialValue: opponent)
        _forScore = State(initialValue: "\(post.scoreFor)")
        _againstScore = State(initialValue: "\(post.scoreAgainst)")
        _note = State(initialValue: post.body)
    }

    private var scoreForValue: Int? {
        Int(forScore.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var scoreAgainstValue: Int? {
        Int(againstScore.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var validationMessage: String? {
        guard let scoreForValue, let scoreAgainstValue else {
            return "Add both scores before saving."
        }
        guard (0...99).contains(scoreForValue), (0...99).contains(scoreAgainstValue) else {
            return "Scores must be between 0 and 99."
        }
        let hasContext = !opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContext else {
            return "Add an opponent or note so the result has context."
        }
        return nil
    }

    var body: some View {
        CreateScaffold(title: "Edit result",
                       subtitle: "Correct this local game result.",
                       canSave: validationMessage == nil,
                       validationMessage: validationMessage,
                       onCancel: { dismiss() },
                       onSave: {
                           let receipt = store.updateResult(id: post.id,
                                                            body: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                                            scoreFor: scoreForValue ?? post.scoreFor,
                                                            scoreAgainst: scoreAgainstValue ?? post.scoreAgainst,
                                                            vs: opponent.trimmingCharacters(in: .whitespacesAndNewlines))
                           onReceipt(receipt)
                           dismiss()
                       }) {
            CPField(label: "Opponent", text: $opponent, placeholder: "Northern")
            HStack(spacing: 12) {
                CPField(label: "Your score", text: $forScore, placeholder: "8", keyboard: .numberPad)
                CPField(label: "Their score", text: $againstScore, placeholder: "5", keyboard: .numberPad)
            }
            CPField(label: "Note", text: $note, placeholder: "Ice was lightning all weekend.")
        }
    }
}

private struct SpielCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: SpielPost

    var body: some View {
        let joined = store.isAttendingSpiel(named: post.spielName)
        VStack(alignment: .leading, spacing: 11) {
            Text("SHARED SPIEL").font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.accent)
            (Text(post.title + " ") + Text(post.spielName).italic())
                .font(.serif(19))
                .foregroundColor(settings.ink)
                .lineSpacing(2)
            HStack(spacing: 11) {
                AvatarStack(initials: store.initials(for: post.who, limit: 4), size: 28, plus: store.plusLabel(for: post.who, visible: 4))
                Text("\(post.whereText)\n\(post.whenText)")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                Button { store.toggleAttendance(forSpielNamed: post.spielName) } label: {
                    Text(joined ? "Going ✓" : "I'm in")
                        .font(.grotesk(13, .bold))
                        .foregroundStyle(joined ? settings.accent : .white)
                        .padding(.vertical, 9).padding(.horizontal, 16)
                        .background(joined ? settings.accent.opacity(0.16) : settings.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(joined ? settings.accent : Color.clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .cpCard(radius: 18, accentBorder: true)
    }
}

private struct ReviewCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: ReviewPost

    var body: some View {
        let author = store.curler(post.author)
        VStack(alignment: .leading, spacing: 9) {
            NavigationLink(value: Route.curler(post.author)) {
                HStack(spacing: 10) {
                    AvatarView(initials: author?.initials ?? "?", size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(author?.name ?? "").font(.grotesk(13, .bold)).foregroundStyle(settings.ink)
                        Text("RINK REVIEW · \(post.time)").font(.mono(10, .medium)).foregroundStyle(settings.muted)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Text(post.rink).font(.serif(16)).foregroundStyle(settings.ink)
            HStack(spacing: 8) {
                (Text(String(repeating: "★", count: post.stars)).foregroundColor(settings.accent)
                    + Text(String(repeating: "★", count: max(0, 5 - post.stars))).foregroundColor(settings.line))
                    .font(.system(size: 13))
                    .tracking(2)
                Text("— \(post.note)").font(.grotesk(13)).foregroundStyle(settings.muted)
            }
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

private struct ResultContextGroup<Content: View>: View {
    @EnvironmentObject var settings: AppSettings
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.mono(10, .medium))
                .tracking(1.5)
                .foregroundStyle(settings.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
            }
        }
    }
}

private struct ResultContextChip: View {
    @EnvironmentObject var settings: AppSettings
    let title: String
    let selected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.grotesk(12, .semibold))
                .foregroundStyle(selected ? .white : settings.ink)
                .lineLimit(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 13)
                .background(selected ? settings.accent : settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Color.clear : settings.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct NewResultSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let onReceipt: (MutationReceipt) -> Void
    @State private var opponent = ""
    @State private var forScore = ""
    @State private var againstScore = ""
    @State private var note = ""
    @State private var selectedStopID: String?
    @State private var selectedParticipantIDs: Set<String> = []

    private var scoreForValue: Int? {
        Int(forScore.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var scoreAgainstValue: Int? {
        Int(againstScore.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var validationMessage: String? {
        guard let scoreForValue, let scoreAgainstValue else {
            return "Add both scores before saving."
        }
        guard (0...99).contains(scoreForValue), (0...99).contains(scoreAgainstValue) else {
            return "Scores must be between 0 and 99."
        }
        let hasContext = !opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContext else {
            return "Add an opponent or note so the result has context."
        }
        return nil
    }

    private var canSave: Bool {
        validationMessage == nil
    }

    private var participantIDs: [String] {
        store.curlers.map(\.id).filter { selectedParticipantIDs.contains($0) }
    }

    var body: some View {
        CreateScaffold(title: "Log a result",
                       subtitle: "Post a game result to your locker room.",
                       canSave: canSave,
                       validationMessage: validationMessage,
                       onCancel: { dismiss() },
                       onSave: {
                           let receipt = store.addResult(body: note.trimmingCharacters(in: .whitespaces),
                                                         scoreFor: scoreForValue ?? 0,
                                                         scoreAgainst: scoreAgainstValue ?? 0,
                                                         vs: opponent.trimmingCharacters(in: .whitespaces),
                                                         stopID: selectedStopID,
                                                         participantCurlerIDs: participantIDs)
                           onReceipt(receipt)
                           dismiss()
                       }) {
            CPField(label: "Opponent", text: $opponent, placeholder: "Northern")
            HStack(spacing: 12) {
                CPField(label: "Your score", text: $forScore, placeholder: "8", keyboard: .numberPad)
                CPField(label: "Their score", text: $againstScore, placeholder: "5", keyboard: .numberPad)
            }
            ResultContextGroup(label: "Rink context") {
                ResultContextChip(title: "No stop",
                                  selected: selectedStopID == nil,
                                  identifier: "curlplan.result.stop.none") {
                    selectedStopID = nil
                }
                ForEach(store.stops) { stop in
                    ResultContextChip(title: stop.name,
                                      selected: selectedStopID == stop.id,
                                      identifier: "curlplan.result.stop.\(stop.id)") {
                        selectedStopID = stop.id
                    }
                }
            }
            ResultContextGroup(label: "Curlers in this game") {
                ForEach(store.curlers) { curler in
                    ResultContextChip(title: curler.name,
                                      selected: selectedParticipantIDs.contains(curler.id),
                                      identifier: "curlplan.result.curler.\(curler.id)") {
                        if selectedParticipantIDs.contains(curler.id) {
                            selectedParticipantIDs.remove(curler.id)
                        } else {
                            selectedParticipantIDs.insert(curler.id)
                        }
                    }
                }
            }
            CPField(label: "Note", text: $note, placeholder: "Ice was lightning all weekend.")
        }
    }
}
