import SwiftUI

// Navigation is private, per-account device state; it is not shared season data.
final class Router: ObservableObject {
    @Published var tab: RootView.Tab = .passport { didSet { persist() } }
    @Published var paths: [RootView.Tab: [Route]] = [:] { didSet { persist() } }
    @Published var invalidLink = false
    private let defaults: UserDefaults
    private var scopeKey: String?
    private var pendingRoute: Route?
    private struct Snapshot: Codable { let tab: RootView.Tab; let paths: [RootView.Tab: [Route]] }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func restore(accountID: String?, store: Store) {
        let key = accountID.map { "cp.navigation.v1:" + $0 }
        guard key != scopeKey else { return }
        if key == nil, let scopeKey { defaults.removeObject(forKey: scopeKey) }
        let saved = key.flatMap { defaults.data(forKey: $0) }.flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        scopeKey = nil
        paths = saved?.paths.mapValues { $0.filter { valid($0, store: store) } } ?? [:]
        tab = saved?.tab ?? .passport
        scopeKey = key
        if key != nil, let pendingRoute {
            self.pendingRoute = nil
            show(pendingRoute)
        }
    }

    func path(for tab: RootView.Tab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func receive(_ url: URL, store: Store) {
        guard let route = Route(url: url), valid(route, store: store) else { invalidLink = true; return }
        if scopeKey == nil { pendingRoute = route }
        else { show(route) }
    }

    private func valid(_ route: Route, store: Store) -> Bool {
        switch route {
        case .stop(let id): return store.stop(id) != nil
        case .curler(let id): return store.curler(id) != nil
        }
    }

    private func show(_ route: Route) {
        switch route {
        case .stop: tab = .passport
        case .curler: tab = .roster
        }
        paths[tab] = [route]
    }

    private func persist() {
        guard let scopeKey, let data = try? JSONEncoder().encode(Snapshot(tab: tab, paths: paths)) else { return }
        defaults.set(data, forKey: scopeKey)
    }
}

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    enum Tab: String, CaseIterable, Codable { case passport, locker, spiels, roster }

    var body: some View {
        Group {
            if store.isSignedIn {
                appShell
            } else {
                AuthView()
            }
        }
        .onAppear { router.restore(accountID: store.currentUser()?.id, store: store) }
        .onChange(of: store.currentUser()?.id) { _, _ in router.restore(accountID: store.currentUser()?.id, store: store) }
        .onOpenURL { router.receive($0, store: store) }
        .alert("Link unavailable", isPresented: $router.invalidLink) {
            Button("OK", role: .cancel) {}
        } message: { Text("This CurlPlan link is invalid or its club or curler is not available on this device.") }
    }

    private var appShell: some View {
        TabView(selection: $router.tab) {
            TabStack(path: router.path(for: .passport)) { PassportView() }
                .tabItem { Label("Passport", systemImage: "map.fill") }
                .tag(Tab.passport)
            TabStack(path: router.path(for: .locker)) { LockerRoomView() }
                .tabItem { Label("Locker", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.locker)
            TabStack(path: router.path(for: .spiels)) { SpielsView() }
                .tabItem { Label("Spiels", systemImage: "calendar") }
                .tag(Tab.spiels)
            TabStack(path: router.path(for: .roster)) { RosterView() }
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
    @Binding var path: [Route]
    @ViewBuilder var content: () -> Content
    var body: some View {
        NavigationStack(path: $path) {
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
