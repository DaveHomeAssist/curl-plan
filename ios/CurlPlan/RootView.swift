import SwiftUI

// Shared tab selection for deep-link and migration flows.
final class Router: ObservableObject {
    @Published var tab: RootView.Tab = .passport
}

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    enum Tab: String, CaseIterable { case passport, locker, spiels, roster }

    var body: some View {
        Group {
            if store.isSignedIn {
                appShell
            } else {
                AuthView()
            }
        }
    }

    private var appShell: some View {
        TabView(selection: $router.tab) {
            TabStack { PassportView() }
                .tabItem { Label("Passport", systemImage: "map.fill") }
                .tag(Tab.passport)
            TabStack { LockerRoomView() }
                .tabItem { Label("Locker", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.locker)
            TabStack { SpielsView() }
                .tabItem { Label("Spiels", systemImage: "calendar") }
                .tag(Tab.spiels)
            TabStack { RosterView() }
                .tabItem { Label("Roster", systemImage: "person.2.fill") }
                .tag(Tab.roster)
        }
        .tint(settings.accent)
        .toolbarBackground(settings.card, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

}

// A NavigationStack that resolves the shared Route destinations.
struct TabStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        NavigationStack {
            content()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .stop(let id): StopDetailView(stopID: id)
                    case .curler(let id): CurlerProfileView(curlerID: id)
                    }
                }
        }
    }
}
