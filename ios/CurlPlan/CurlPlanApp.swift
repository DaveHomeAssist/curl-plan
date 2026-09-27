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
        } else if ProcessInfo.processInfo.arguments.contains("--contrast-components") {
            ContrastComponentsControl()
        } else if ProcessInfo.processInfo.arguments.contains("--large-type-audit") {
            RootView().dynamicTypeSize(.accessibility5)
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

#if DEBUG
private struct ContrastComponentsControl: View {
    @EnvironmentObject var settings: AppSettings
    private var samples: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Component contrast control").font(.headline).foregroundStyle(settings.ink)
            Text("Totals reflect your saved visits and results on this device. Sample club records are separate.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
            SectionHeader(title: "Your visits")
            HStack {
                StatCell(value: "1", label: "CLUBS")
                StatCell(value: "100%", label: "WIN", accent: true)
            }.padding(14).cpCard()
            HStack {
                PillButton(title: "Log visit") {}
                PillButton(title: "Ice read", filled: false) {}
            }
            Text("Kelowna, BC").font(.mono(11, .medium)).foregroundStyle(settings.muted)
            HStack {
                StatCell(value: "1", label: "WITHOUT SHADOW")
                Text("1").font(.serif(26)).foregroundStyle(settings.ink)
                    .accessibilityIdentifier("control-direct-statistic")
            }.padding(14).background(settings.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(settings.line, lineWidth: 1))

            HStack(spacing: 24) {
                Text("1").font(.system(size: 26, weight: .bold)).foregroundStyle(.black)
                    .padding(24).background(.white).accessibilityIdentifier("control-black-one")
                Text("1").font(.serif(26, .semibold)).foregroundStyle(settings.ink)
                    .padding(24).background(.white).accessibilityIdentifier("control-ink-one")
                Text("Black text").font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                    .padding(24).background(.white).accessibilityIdentifier("control-black-text")
            }

        }.padding(24)
    }
    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("--control-scroll") {
                ScrollView { samples }
            } else { samples }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(settings.screen)
    }
}
#endif
