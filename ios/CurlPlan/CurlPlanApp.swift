import SwiftUI

// CurlPlan — native SwiftUI port of the "Passport + Locker Room" Hi-Fi concept.
// Single window, custom tab bar, per-tab navigation stacks. Theming (Ice/Arena,
// accent, pebble) is persisted via AppSettings and shared through the environment.

@main
struct CurlPlanApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .tint(settings.accent)
                .preferredColorScheme(settings.isArena ? .dark : .light)
        }
    }
}
