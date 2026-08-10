import SwiftUI

// Credential-free product preview. Real account controls stay unavailable until
// the Clerk + D1 backend is configured and verified end to end.
struct AuthView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                HouseRing(size: 22)
                Text("CurlPlan").font(.grotesk(19, .bold)).foregroundStyle(settings.ink)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    VStack(spacing: 10) {
                        HouseRing(size: 46)
                        Text("Your season, your circle")
                            .font(.serif(32)).foregroundStyle(settings.ink)
                            .multilineTextAlignment(.center)
                        Eyebrow(text: "A working CurlPlan product preview")
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 14) {
                        (Text("Demo only. ").foregroundStyle(settings.accent)
                            + Text("Accounts and cloud sync are not live yet, so CurlPlan will never ask for your email or password in this preview.").foregroundStyle(settings.ink))
                            .font(.grotesk(14, .semibold))
                            .lineSpacing(3)

                        Button { store.exploreDemo() } label: {
                            Text("Explore the demo")
                                .font(.grotesk(14, .bold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(settings.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Text("Demo changes stay on this device. Real account recovery, deletion, and cross-device restore will ship only with the verified backend.")
                            .font(.grotesk(13, .medium))
                            .foregroundStyle(settings.muted)
                            .lineSpacing(2)
                    }
                    .padding(18)
                    .cpCard(radius: 18)

                    Text("No credentials are collected or transmitted.")
                        .font(.grotesk(14, .medium))
                        .foregroundStyle(settings.muted)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.screen)
    }
}
