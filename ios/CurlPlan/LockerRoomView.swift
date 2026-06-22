import SwiftUI

struct LockerRoomView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNew = false
    @State private var searching = false
    @State private var query = ""

    private var filteredFeed: [FeedItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.feed }
        return store.feed.filter { feedMatches($0, q) }
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
                .padding(.bottom, 8)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    if filteredFeed.isEmpty {
                        Text("No posts match \"\(query)\".")
                            .font(.grotesk(13)).foregroundStyle(settings.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(filteredFeed) { item in
                        FeedCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .overlay(alignment: .bottomTrailing) {
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
            .padding(.trailing, 18)
            .padding(.bottom, 104)
        }
        .sheet(isPresented: $showingNew) { NewResultSheet() }
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
            }
            HStack(spacing: 22) {
                VStack(spacing: 9) {
                    Text("Following").font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                    settings.accent.frame(height: 2.5)
                }
                .fixedSize()
                Text("Discover").font(.grotesk(14, .medium)).foregroundStyle(settings.muted)
                    .padding(.bottom, 11)
                Spacer()
            }
            .overlay(alignment: .bottom) { settings.line.frame(height: 1) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

struct FeedCard: View {
    let item: FeedItem
    var body: some View {
        switch item {
        case .result(let p): ResultCard(post: p)
        case .spiel(let p): SpielCard(post: p)
        case .review(let p): ReviewCard(post: p)
        }
    }
}

private struct ResultCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: ResultPost

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

            HStack(spacing: 20) {
                Label("\(post.likes)", systemImage: "heart").labelStyle(.titleAndIcon)
                Label("\(post.comments)", systemImage: "bubble.right")
                Spacer()
                Image(systemName: "arrowshape.turn.up.right")
            }
            .font(.grotesk(13, .semibold))
            .foregroundStyle(settings.muted)
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

private struct SpielCard: View {
    @EnvironmentObject var settings: AppSettings
    @State private var joined = false
    let post: SpielPost

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("SHARED SPIEL").font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.accent)
            (Text(post.title + " ") + Text(post.spielName).italic())
                .font(.serif(19))
                .foregroundColor(settings.ink)
                .lineSpacing(2)
            HStack(spacing: 11) {
                AvatarStack(initials: post.who.map { _ in "" }, size: 28)
                Text("\(post.whereText)\n\(post.whenText)")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                Button { joined.toggle() } label: {
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

struct NewResultSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var opponent = ""
    @State private var forScore = ""
    @State private var againstScore = ""
    @State private var note = ""

    private var canSave: Bool {
        Int(forScore.trimmingCharacters(in: .whitespaces)) != nil &&
        Int(againstScore.trimmingCharacters(in: .whitespaces)) != nil
    }

    var body: some View {
        CreateScaffold(title: "Log a result",
                       subtitle: "Post a game result to your locker room.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           store.addResult(body: note.trimmingCharacters(in: .whitespaces),
                                           scoreFor: Int(forScore) ?? 0,
                                           scoreAgainst: Int(againstScore) ?? 0,
                                           vs: opponent.trimmingCharacters(in: .whitespaces))
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
