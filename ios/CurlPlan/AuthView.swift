import SwiftUI

// Sign in / create account / explore demo. Local-first identity with the same
// backend-ready seam the web app documents (swap Store.signIn/signUp for a real API
// or Clerk). Parity with the web viewAuth() screen.
struct AuthView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    private enum Mode { case signin, signup }
    @State private var mode: Mode = .signin
    @State private var name = ""
    @State private var club = ""
    @State private var role = "Skip"
    @State private var email = ""
    @State private var password = ""
    @State private var error = ""

    private var isSignup: Bool { mode == .signup }

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
                        Text(isSignup ? "Join the circle" : "Welcome back")
                            .font(.serif(32)).foregroundStyle(settings.ink)
                        Eyebrow(text: isSignup ? "Your season, your circle" : "Sign in to your season")
                    }
                    .padding(.top, 20)

                    card
                    altLinks
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.screen)
    }

    private var card: some View {
        VStack(spacing: 13) {
            // mode segment
            HStack(spacing: 6) {
                seg("Sign in", on: !isSignup) { mode = .signin; error = "" }
                seg("Create account", on: isSignup) { mode = .signup; error = "" }
            }

            if !error.isEmpty {
                Text(error)
                    .font(.grotesk(12, .semibold)).foregroundStyle(settings.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(settings.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if isSignup {
                CPField(label: "Name", text: $name, placeholder: "Dana Mercer")
                ClubField(text: $club)
                CPChips(label: "Position", options: ["Skip", "Third", "Second", "Lead", "Spare"], selection: $role)
            }
            CPField(label: "Email", text: $email, placeholder: "you@club.ca", keyboard: .emailAddress)
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSWORD").font(.mono(10, .medium)).tracking(1.5).foregroundStyle(settings.muted)
                SecureField(isSignup ? "6+ characters" : "Your password", text: $password)
                    .font(.grotesk(15)).foregroundStyle(settings.ink).tint(settings.accent)
                    .padding(.vertical, 11).padding(.horizontal, 13)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
                if isSignup {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(settings.line)
                            Capsule().fill(settings.accent).frame(width: geo.size.width * pwStrength)
                        }
                    }
                    .frame(height: 5)
                }
            }

            Button { submit() } label: {
                Text(isSignup ? "Create account" : "Sign in")
                    .font(.grotesk(14, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(settings.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(18)
        .cpCard(radius: 18)
    }

    private var altLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(isSignup ? "Already curling here?" : "New here?")
                    .font(.grotesk(13, .medium)).foregroundStyle(settings.muted)
                Button(isSignup ? "Sign in" : "Create an account") {
                    mode = isSignup ? .signin : .signup; error = ""
                }
                .font(.grotesk(13, .bold)).foregroundStyle(settings.accent)
                .buttonStyle(.plain)
            }
            Button("Explore the demo →") { store.exploreDemo() }
                .font(.grotesk(13, .bold)).foregroundStyle(settings.accent)
                .buttonStyle(.plain)
        }
    }

    private var pwStrength: Double {
        let v = password
        var score = min(4, v.count / 3)
        if v.range(of: #"[^a-zA-Z0-9]"#, options: .regularExpression) != nil { score += 1 }
        return min(1.0, Double(score) * 0.22)
    }

    private func seg(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.grotesk(12, .semibold))
                .foregroundStyle(on ? .white : settings.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(on ? settings.accent : settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        let result: Store.AuthResult = isSignup
            ? store.signUp(name: name, email: email, pass: password, club: club, role: role, prov: "")
            : store.signIn(email: email, pass: password)
        switch result {
        case .ok: error = ""       // RootView re-renders on the published auth change
        case .error(let m): error = m
        }
    }
}
