import SwiftUI

// Credential-free product preview. Real account controls stay unavailable until
// the Clerk + D1 backend is configured and verified end to end.
struct AuthView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @EnvironmentObject var accountRuntime: AccountRuntime

    @State private var recoveryPassword = ""
    @State private var recoveryMessage = ""

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

                    if hasPendingDevelopmentRecovery {
                        recoveryCard
                    } else {
                        demoCard

                        Text("No credentials are collected or transmitted.")
                            .font(.grotesk(14, .medium))
                            .foregroundStyle(settings.muted)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.screen)
    }

    private var hasPendingDevelopmentRecovery: Bool {
        accountRuntime.isConfigured &&
            [.recovery, .working].contains(accountRuntime.state.kind) &&
            accountRuntime.pendingLifecycle != nil
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("Demo only. ").foregroundStyle(settings.accent)
                + Text("The public product preview does not offer account creation or cloud sync and does not ask for credentials.").foregroundStyle(settings.ink))
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
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Development recovery")

            Text(accountRuntime.state.title)
                .font(.serif(23))
                .foregroundStyle(settings.ink)

            Text(accountRuntime.state.detail)
                .font(.grotesk(13, .medium))
                .foregroundStyle(settings.muted)
                .lineSpacing(2)

            SecureField("Password for @\(accountRuntime.pendingLifecycle?.handle ?? "account")", text: $recoveryPassword)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .disabled(accountRuntime.isBusy)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(settings.screen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHint("Required to retry or roll back the interrupted development account setup.")

            Button(action: retryPendingAccount) {
                Text("Retry account setup")
                    .font(.grotesk(14, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(settings.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(recoveryActionDisabled)

            Button(action: rollBackPendingAccount) {
                Text("Roll back partial account")
                    .font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(settings.ink.opacity(0.24), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(recoveryActionDisabled)
            .accessibilityHint("Deletes the partial development account while preserving this device's local season.")

            if accountRuntime.isBusy {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(accountRuntime.state.detail)
            }

            if !recoveryMessage.isEmpty {
                Text(recoveryMessage)
                    .font(.grotesk(13, .medium))
                    .foregroundStyle(settings.muted)
                    .accessibilityLabel("Recovery status: \(recoveryMessage)")
            }

            Text("This control appears only for an explicitly enabled development backend with an interrupted account setup. The entered password is sent only to that configured verifier and is not stored on this device.")
                .font(.grotesk(12, .medium))
                .foregroundStyle(settings.muted)
        }
        .padding(18)
        .cpCard(radius: 18)
    }

    private var recoveryActionDisabled: Bool {
        accountRuntime.isBusy || recoveryPassword.count < 8
    }

    private func retryPendingAccount() {
        guard let pending = accountRuntime.pendingLifecycle else { return }
        let password = recoveryPassword
        let season = AccountSeasonPayload(
            profile: .blank(name: store.me.name, homeClub: store.me.club, province: store.me.prov),
            state: store.state
        )
        Task {
            let result = await accountRuntime.createAccount(handle: pending.handle, password: password, season: season)
            recoveryPassword = ""
            recoveryMessage = result.message
        }
    }

    private func rollBackPendingAccount() {
        let password = recoveryPassword
        Task {
            let result = await accountRuntime.rollbackPendingAccount(password: password)
            recoveryPassword = ""
            recoveryMessage = result.message
        }
    }
}
