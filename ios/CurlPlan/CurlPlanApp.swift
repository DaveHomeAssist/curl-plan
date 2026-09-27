import SwiftUI

// CurlPlan — native SwiftUI port of the "Passport + Locker Room" Hi-Fi concept.
// Single window, custom tab bar, per-tab navigation stacks. Theming (Ice/Arena,
// accent, pebble) is persisted via AppSettings and shared through the environment.

@main
struct CurlPlanApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = Store()
    @StateObject private var router = Router()

    @ViewBuilder private var content: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--contrast-control") {
            VStack(spacing: 24) {
                Text("Black text on white").font(.system(size: 18, weight: .bold)).foregroundStyle(.black).padding().background(.white)
                Text("White text on black").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).padding().background(.black)
                Text("Muted text on white").font(.mono(11, .semibold)).foregroundStyle(Color(hex: 0x465159)).padding().background(.white)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(.white)
        } else { RootView() }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            content
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(router)
                .tint(settings.accent)
                .preferredColorScheme(settings.isArena ? .dark : .light)
        }
    }
}
