import SwiftUI

// Shared tab selection so any screen (e.g. Passport's "All → Spiels") can switch tabs,
// and so deep-link / migration flows have a single place to drive navigation.
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
        ZStack(alignment: .bottom) {
            settings.screen.ignoresSafeArea()

            // all four stacks stay alive so pushed routes and scroll positions
            // survive tab switches; only the active one is visible and hit-testable
            ZStack {
                pane(.passport) { PassportView() }
                pane(.locker) { LockerRoomView() }
                pane(.spiels) { SpielsView() }
                pane(.roster) { RosterView() }
            }

            CPTabBar(tab: $router.tab)
        }
    }

    private func pane<Content: View>(_ t: Tab, @ViewBuilder content: @escaping () -> Content) -> some View {
        TabStack(content: content)
            .opacity(router.tab == t ? 1 : 0)
            .allowsHitTesting(router.tab == t)
            .accessibilityHidden(router.tab != t)
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

struct CPTabBar: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var tab: RootView.Tab

    var body: some View {
        HStack(spacing: 0) {
            item(.passport, "Passport", symbol: nil)
            item(.locker, "Locker", symbol: "bubble.left.and.bubble.right.fill")
            item(.spiels, "Spiels", symbol: "calendar")
            item(.roster, "Roster", symbol: "person.2.fill")
        }
        .padding(.top, 11)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            settings.card
                .overlay(Rectangle().fill(settings.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }

    private func item(_ t: RootView.Tab, _ title: String, symbol: String?) -> some View {
        let active = tab == t
        return Button {
            tab = t
        } label: {
            VStack(spacing: 5) {
                Group {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(active ? settings.accent : settings.ink)
                    } else {
                        HouseRing(size: 21).saturation(active ? 1 : 0.4)
                    }
                }
                .frame(height: 22)
                Text(title)
                    .font(.grotesk(10, active ? .semibold : .medium))
                    .foregroundStyle(active ? settings.accent : settings.ink)
            }
            .frame(maxWidth: .infinity)
            .opacity(active ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
