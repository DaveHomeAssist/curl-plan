import SwiftUI

struct LockerRoomView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingCompose = false
    @State private var searching = false
    @State private var query = ""
    private enum LockerTab { case following, discover }
    @State private var lockerTab: LockerTab = .following

    private var filteredFeed: [Post] {
        var list = store.allPosts
        if lockerTab == .following {
            // Following = your posts, shared spiels, and posts by curlers you follow
            list = list.filter { p in
                if p.author == "me" || p.kind == .spiel { return true }
                if let a = p.author, let c = store.curler(a) { return store.isFollowing(c.id) }
                return true
            }
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter { postMatches($0, q) }
    }

    private func postMatches(_ p: Post, _ q: String) -> Bool {
        let authorName = p.author.flatMap { store.curler($0)?.name } ?? (p.author == "me" ? store.me.name : "")
        let hay = [authorName, p.body, p.vs, p.club, p.note, p.spielName, p.title, p.whereText]
            .compactMap { $0 }.joined(separator: " ")
        return hay.localizedCaseInsensitiveContains(q)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if searching {
                SearchField(placeholder: "Search the feed", query: $query)
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 13) {
                    if filteredFeed.isEmpty {
                        Text("No posts match \"\(query)\".")
                            .font(.grotesk(13)).foregroundStyle(settings.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(filteredFeed) { post in
                        FeedCard(post: post)
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
            Button { showingCompose = true } label: {
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
        .sheet(isPresented: $showingCompose) { ComposeSheet() }
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
                feedTab("Following", .following)
                feedTab("Discover", .discover)
                Spacer()
            }
            .overlay(alignment: .bottom) { settings.line.frame(height: 1) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func feedTab(_ title: String, _ tab: LockerTab) -> some View {
        let on = lockerTab == tab
        return Button { lockerTab = tab } label: {
            VStack(spacing: 9) {
                Text(title)
                    .font(.grotesk(14, on ? .bold : .medium))
                    .foregroundStyle(on ? settings.ink : settings.muted)
                (on ? settings.accent : Color.clear).frame(height: 2.5)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// Reusable inline search field.
struct SearchField: View {
    @EnvironmentObject var settings: AppSettings
    let placeholder: String
    @Binding var query: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(settings.muted)
            TextField(placeholder, text: $query)
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
    }
}

struct FeedCard: View {
    let post: Post
    var body: some View {
        switch post.kind {
        case .result: ResultCard(post: post)
        case .note:   NoteCard(post: post)
        case .review: ReviewCard(post: post)
        case .spiel:  SpielPromoCard(post: post)
        }
    }
}

// Shared post header (avatar + name + meta + ⋯) with optional nav to the author.
private struct PostHead: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: Post
    var metaOverride: String? = nil
    var avatarSize: CGFloat = 38
    var nameSize: CGFloat = 14
    var metaSize: CGFloat = 11
    var showMenu: Bool = true

    var body: some View {
        let author = post.author.flatMap { store.curler($0) }
        let isMe = post.author == "me" || author == nil
        let name = author?.name ?? (post.author == "me" ? store.me.name : "Unknown curler")
        let initials = author?.initials ?? (post.author == "me" ? store.me.initials : "?")
        let meta = metaOverride ?? ((author.map { "\($0.role.uppercased()) · \($0.club.uppercased())" } ?? "YOU") + " · \(displayTime(post))")
        let head = HStack(spacing: 10) {
            AvatarView(initials: initials, size: avatarSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.grotesk(nameSize, .bold)).foregroundStyle(settings.ink)
                Text(meta).font(.mono(metaSize, .medium)).foregroundStyle(settings.muted)
            }
            Spacer()
            if showMenu { Image(systemName: "ellipsis").foregroundStyle(settings.muted) }
        }
        if let author, !isMe {
            NavigationLink(value: Route.curler(author.id)) { head }.buttonStyle(.plain)
        } else {
            head
        }
    }
}

private func displayTime(_ p: Post) -> String {
    if let at = p.at { return RelativeTime.ago(at) }
    return p.time ?? ""
}

private struct ResultCard: View {
    @EnvironmentObject var settings: AppSettings
    let post: Post
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            PostHead(post: post)
            if let body = post.body, !body.isEmpty {
                Text(body).font(.grotesk(15)).foregroundStyle(settings.ink).lineSpacing(2)
            }
            HStack(spacing: 11) {
                (Text("\(post.scoreFor ?? 0)").foregroundColor(settings.ink)
                    + Text(" – ").foregroundColor(settings.muted)
                    + Text("\(post.scoreAgainst ?? 0)").foregroundColor(settings.ink))
                    .font(.serif(28))
                Text(post.res ?? "")
                    .font(.mono(9, .bold)).tracking(1).foregroundStyle(.white)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(settings.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Spacer()
                Text(post.vs ?? "").font(.mono(11, .medium)).foregroundStyle(settings.muted)
            }
            .padding(.vertical, 10).padding(.horizontal, 13)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

private struct NoteCard: View {
    @EnvironmentObject var settings: AppSettings
    let post: Post
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            PostHead(post: post)
            Text(post.body ?? "").font(.grotesk(15)).foregroundStyle(settings.ink).lineSpacing(2)
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

private struct ReviewCard: View {
    @EnvironmentObject var settings: AppSettings
    let post: Post
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PostHead(post: post, metaOverride: "CLUB REVIEW · \(displayTime(post))",
                     avatarSize: 32, nameSize: 13, metaSize: 10, showMenu: false)
            Text(post.club ?? "").font(.serif(16)).foregroundStyle(settings.ink)
            HStack(spacing: 8) {
                StarsRow(count: post.stars ?? 0)
                Text("— \(post.note ?? "")").font(.grotesk(13)).foregroundStyle(settings.muted)
            }
        }
        .padding(14)
        .cpCard(radius: 18)
    }
}

// Shared-spiel promo — registration is unified with the Spiels tab via spielId.
private struct SpielPromoCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    let post: Post

    var body: some View {
        let joined = post.spielId.map { store.spielStatus($0) == "You're in" } ?? false
        return VStack(alignment: .leading, spacing: 11) {
            Text("SHARED SPIEL").font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.accent)
            (Text((post.title ?? "") + " ") + Text(post.spielName ?? "").italic())
                .font(.serif(19))
                .foregroundColor(settings.ink)
                .lineSpacing(2)
            HStack(spacing: 11) {
                AvatarStack(initials: (post.who ?? []).map { store.curler($0)?.initials ?? "?" }, size: 28)
                Text("\(post.whereText ?? "")\n\(post.whenText ?? "")")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                if let sid = post.spielId {
                    Button {
                        if joined { store.withdrawSpiel(sid) } else { store.setSpielStatus(sid, "You're in") }
                    } label: {
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
        }
        .padding(14)
        .cpCard(radius: 18, accentBorder: true)
    }
}
