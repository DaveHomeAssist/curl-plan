import SwiftUI

struct RosterView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Roster").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(settings.ink)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your circle · \(store.curlers.count) curlers")
                    VStack(spacing: 12) {
                        ForEach(store.curlers) { c in
                            RosterRow(curler: c)
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
            Spacer()
            PillButton(title: curler.following ? "Following" : "Follow", filled: !curler.following) {
                store.toggleFollow(curler.id)
            }
        }
        .padding(12)
        .cpCard()
    }
}
