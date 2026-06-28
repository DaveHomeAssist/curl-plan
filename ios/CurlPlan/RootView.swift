import SwiftUI

struct RootView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    enum Tab: String, CaseIterable { case passport, map, locker, spiels, roster }
    @State private var tab: Tab = .passport

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView()
            } else {
                ZStack(alignment: .bottom) {
                    settings.screen.ignoresSafeArea()

                    Group {
                        switch tab {
                        case .passport: TabStack { PassportView() }
                        case .map:      TabStack { LiveMapView() }
                        case .locker:   TabStack { LockerRoomView() }
                        case .spiels:   TabStack { SpielsView() }
                        case .roster:   TabStack { RosterView() }
                        }
                    }

                    CPTabBar(tab: $tab)
                }
                .accessibilityIdentifier("curlplan.main")
            }
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var name = ""
    @State private var homeClub = ""
    @State private var province = "BC"
    @State private var showImport = false

    var body: some View {
        ZStack {
            settings.screen.ignoresSafeArea()
            PebbleOverlay(opacity: settings.pebbleOpacity)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        HouseRing(size: 28)
                        Text("CurlPlan")
                            .font(.grotesk(22, .bold))
                            .foregroundStyle(settings.ink)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "First launch")
                        Text("Set up your season")
                            .font(.serif(38))
                            .foregroundStyle(settings.ink)
                        Text("Start with demo data, create a blank season, or restore a saved CurlPlan export.")
                            .font(.grotesk(15))
                            .foregroundStyle(settings.muted)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        CPField(label: "Your name", text: $name, placeholder: "Dana Mercer")
                        CPField(label: "Home rink", text: $homeClub, placeholder: "Calgary Granite CC")
                        CPField(label: "Province", text: $province, placeholder: "BC")
                    }
                    .padding(16)
                    .cpCard(radius: 18)

                    VStack(spacing: 10) {
                        setupButton(title: "Use demo season",
                                    subtitle: "Load the seeded Passport, map, roster, and locker room.",
                                    filled: true) {
                            store.startDemoSeason()
                        }

                        setupButton(title: "Start blank season",
                                    subtitle: "Create a real season with empty tabs and recovery tools.",
                                    filled: false) {
                            store.startBlankSeason(name: name, homeClub: homeClub, province: province)
                        }

                        setupButton(title: "Import saved season",
                                    subtitle: "Paste a CurlPlan JSON export and resume from that state.",
                                    filled: false) {
                            showImport = true
                        }
                    }

                    Text("You can reset, export, or import later from Settings.")
                        .font(.mono(10, .medium))
                        .tracking(1)
                        .foregroundStyle(settings.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
                .cpReadableContent(maxWidth: 560, alignment: .leading)
            }
        }
        .accessibilityIdentifier("curlplan.onboarding")
        .sheet(isPresented: $showImport) {
            SeasonImportSheet(title: "Import season",
                              subtitle: "Paste a CurlPlan JSON export to restore your season.")
        }
    }

    private func setupButton(title: String, subtitle: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.grotesk(15, .bold))
                        .foregroundStyle(filled ? .white : settings.ink)
                    Text(subtitle)
                        .font(.grotesk(12))
                        .foregroundStyle(filled ? .white.opacity(0.78) : settings.muted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(filled ? .white : settings.accent)
            }
            .padding(15)
            .background(filled ? settings.accent : settings.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(filled ? Color.clear : settings.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("curlplan.setup.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
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
            item(.map, "Map", symbol: "map")
            item(.locker, "Locker", symbol: "bubble.left.and.bubble.right.fill")
            item(.spiels, "Spiels", symbol: "calendar")
            item(.roster, "Roster", symbol: "person.2.fill")
        }
        .frame(maxWidth: CPLayout.tabBarWidth)
        .frame(maxWidth: .infinity)
        .padding(.top, 11)
        .padding(.bottom, 8)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityIdentifier("curlplan.tab.\(title.lowercased())")
    }
}
