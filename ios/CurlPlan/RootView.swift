import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings

    enum Tab: String, CaseIterable { case passport, locker, spiels, roster }
    @State private var tab: Tab = .passport

    var body: some View {
        ZStack(alignment: .bottom) {
            settings.screen.ignoresSafeArea()

            Group {
                switch tab {
                case .passport: TabStack { PassportView() }
                case .locker:   TabStack { LockerRoomView() }
                case .spiels:   TabStack { SpielsView() }
                case .roster:   TabStack { RosterView() }
                }
            }

            CPTabBar(tab: $tab)
        }
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
