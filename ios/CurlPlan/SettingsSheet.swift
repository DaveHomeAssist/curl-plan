import SwiftUI
import UIKit

struct SettingsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @EnvironmentObject var accountRuntime: AccountRuntime
    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: SettingsDataAction?
    @State private var pendingAccountAction: AccountSettingsAction?
    @State private var dataMessage: String?
    @State private var dataMessageIsError = false
    @State private var accountMessage: String?
    @State private var accountMessageIsError = false
    @State private var localExportJSON: String?
    @State private var showingImport = false
    @State private var credentialMode: AccountCredentialMode?

    var body: some View {
        settingsContent
    }

    private var settingsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 14)

            HStack {
                Text("Appearance").font(.serif(24)).foregroundStyle(settings.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.grotesk(14, .bold))
                    .foregroundStyle(settings.accent)
                    .accessibilityIdentifier("curlplan.settings.done")
            }
            Text("Same season, local roster - tune the ice.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 4)

            settingRow(title: "Theme", sub: "ICE / ARENA") {
                HStack(spacing: 6) {
                    seg("Ice", on: settings.theme == .ice) { settings.theme = .ice }
                    seg("Arena", on: settings.theme == .arena) { settings.theme = .arena }
                }
            }

            settingRow(title: "Accent", sub: "HOUSE COLOUR") {
                HStack(spacing: 8) {
                    ForEach(AppSettings.accents, id: \.key) { a in
                        Button { settings.accentKey = a.key } label: {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(a.color)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(settings.ink, lineWidth: settings.accentKey == a.key ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            settingRow(title: "Pebble texture", sub: "ICE GRAIN OVERLAY") {
                Toggle("", isOn: Binding(get: { settings.pebble }, set: { settings.pebble = $0 }))
                    .labelsHidden()
                    .tint(settings.accent)
            }

            Text("Data")
                .font(.serif(22))
                .foregroundStyle(settings.ink)
                .padding(.top, 18)
                .padding(.bottom, 4)

            if let dataMessage {
                Text(dataMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(dataMessageIsError ? settings.houseRed : settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("curlplan.settings.dataMessage")
            }

            dataButtonRow(title: "Export season", sub: "COPY FULL JSON TO CLIPBOARD", systemImage: "square.and.arrow.up") {
                let json = store.exportJSON()
                localExportJSON = json
                UIPasteboard.general.string = json
                dataMessage = "Season export copied."
                dataMessageIsError = false
            }
            dataButtonRow(title: "Import season", sub: "RESTORE LAST EXPORT OR CLIPBOARD", systemImage: "square.and.arrow.down") {
                showingImport = true
            }
            dataButtonRow(title: "Reset demo", sub: "LOAD SEEDED CURLPLAN DATA", systemImage: "arrow.clockwise") {
                pendingAction = .resetDemo
            }
            dataButtonRow(title: "Clear season", sub: "KEEP PROFILE, REMOVE SEASON DATA", systemImage: "trash") {
                pendingAction = .clearSeason
            }
            dataButtonRow(title: "Show setup", sub: "RETURN TO FIRST LAUNCH CHOICES", systemImage: "person.crop.circle.badge.questionmark") {
                pendingAction = .setup
            }

            if accountRuntime.isConfigured {
                accountSection
            }

            Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
        .confirmationDialog(pendingAction?.title ?? "Confirm",
                            isPresented: Binding(get: { pendingAction != nil },
                                                 set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible) {
            if let pendingAction {
                Button(pendingAction.confirmTitle, role: pendingAction.role) {
                    run(pendingAction)
                    self.pendingAction = nil
                }
                .accessibilityIdentifier("curlplan.settings.confirm.\(pendingAction.id)")
                Button("Cancel", role: .cancel) { self.pendingAction = nil }
            }
        } message: {
            Text(pendingAction?.message ?? "")
        }
        .confirmationDialog(pendingAccountAction?.title ?? "Confirm",
                            isPresented: Binding(get: { pendingAccountAction != nil },
                                                 set: { if !$0 { pendingAccountAction = nil } }),
                            titleVisibility: .visible) {
            if let pendingAccountAction {
                Button(pendingAccountAction.confirmTitle, role: pendingAccountAction.role) {
                    runAccount(pendingAccountAction)
                    self.pendingAccountAction = nil
                }
                .accessibilityIdentifier("curlplan.settings.confirm.\(pendingAccountAction.id)")
                Button("Cancel", role: .cancel) { self.pendingAccountAction = nil }
            }
        } message: {
            Text(pendingAccountAction?.message ?? "")
        }
        .sheet(isPresented: $showingImport) {
            SeasonImportSheet(title: "Import season",
                              subtitle: "Review a CurlPlan JSON export before replacing this season.",
                              initialText: localExportJSON ?? "") { receipt in
                dataMessage = receipt.userMessage
                dataMessageIsError = false
                showingImport = false
            }
        }
        .sheet(item: $credentialMode) { mode in
            AccountCredentialSheet(mode: mode, initialHandle: accountRuntime.savedHandle ?? "") { handle, password in
                runCredential(mode, handle: handle, password: password)
            }
            .environmentObject(settings)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dev account backend")
                .font(.serif(22))
                .foregroundStyle(settings.ink)
                .padding(.top, 18)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(accountRuntime.state.title)
                    .font(.grotesk(14, .semibold))
                    .foregroundStyle(accountRuntime.state.kind == .failed ? settings.houseRed : settings.ink)
                Text(accountRuntime.state.detail)
                    .font(.mono(10, .medium))
                    .foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let accountID = accountRuntime.state.accountID {
                    Text("Account \(accountID.prefix(12))")
                        .font(.mono(10, .regular))
                        .foregroundStyle(settings.muted)
                }
            }
            .padding(.vertical, 10)
            .accessibilityIdentifier("curlplan.settings.account.status")

            if let accountMessage {
                Text(accountMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(accountMessageIsError ? settings.houseRed : settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("curlplan.settings.account.message")
            }

            if accountRuntime.isConfigured {
                if accountRuntime.isSignedIn {
                    dataButtonRow(title: "Export backend data",
                                  sub: "REQUEST BACKEND EXPORT SECTIONS",
                                  systemImage: "tray.and.arrow.up",
                                  isDisabled: accountRuntime.isBusy) {
                        runAccount(.export)
                    }
                    dataButtonRow(title: "Sign out backend",
                                  sub: "REVOKE THIS BACKEND SESSION",
                                  systemImage: "rectangle.portrait.and.arrow.right",
                                  isDisabled: accountRuntime.isBusy) {
                        runAccount(.signOut)
                    }
                    dataButtonRow(title: "Delete dev account",
                                  sub: "API DELETE, SESSIONS REVOKED",
                                  systemImage: "person.crop.circle.badge.xmark",
                                  isDisabled: accountRuntime.isBusy) {
                        pendingAccountAction = .delete
                    }
                } else {
                    dataButtonRow(title: "Create dev account",
                                  sub: "SET A HANDLE AND PASSWORD, IMPORT THIS SEASON",
                                  systemImage: "person.crop.circle.badge.plus",
                                  isDisabled: accountRuntime.isBusy) {
                        credentialMode = .create
                    }
                    dataButtonRow(title: "Sign in to dev account",
                                  sub: "LOAD SEASON FROM CONFIGURED BACKEND",
                                  systemImage: "arrow.down.doc",
                                  isDisabled: accountRuntime.isBusy) {
                        credentialMode = .signIn
                    }
                }
            }
        }
    }

    private func settingRow<Control: View>(title: String, sub: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(settings.line).frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.grotesk(14, .semibold)).foregroundStyle(settings.ink)
                    Text(sub).font(.mono(11, .regular)).tracking(0.5).foregroundStyle(settings.muted)
                }
                Spacer()
                control()
            }
            .padding(.vertical, 13)
        }
    }

    private func dataButtonRow(title: String,
                               sub: String,
                               systemImage: String,
                               isDisabled: Bool = false,
                               action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(settings.line).frame(height: 1)
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(settings.accent)
                        .frame(width: 28, height: 28)
                        .background(settings.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.grotesk(14, .semibold)).foregroundStyle(settings.ink)
                        Text(sub).font(.mono(11, .regular)).tracking(0.5).foregroundStyle(settings.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(settings.muted)
                }
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityLabel(title)
            .accessibilityIdentifier("curlplan.settings.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        }
    }

    private func seg(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.grotesk(12, .semibold))
                .foregroundStyle(on ? .white : settings.ink)
                .padding(.vertical, 7).padding(.horizontal, 12)
                .background(on ? settings.accent : settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func run(_ action: SettingsDataAction) {
        let receipt: MutationReceipt
        switch action {
        case .resetDemo:
            receipt = store.startDemoSeason()
        case .clearSeason:
            receipt = store.clearSeason()
        case .setup:
            receipt = store.resetToSetup()
        }
        dataMessage = receipt.userMessage
        dataMessageIsError = false
    }

    private func runAccount(_ action: AccountSettingsAction) {
        accountMessage = "Contacting account backend..."
        accountMessageIsError = false
        Task {
            let result: AccountRuntimeResult
            switch action {
            case .export:
                result = await accountRuntime.exportAccountData()
            case .signOut:
                result = await accountRuntime.signOut()
            case .delete:
                result = await accountRuntime.deleteAccount()
            }
            accountMessage = result.message
            accountMessageIsError = accountRuntime.state.kind == .failed
        }
    }

    private func runCredential(_ mode: AccountCredentialMode, handle: String, password: String) {
        accountMessage = "Contacting account backend..."
        accountMessageIsError = false
        credentialMode = nil
        Task {
            let result: AccountRuntimeResult
            switch mode {
            case .create:
                result = await accountRuntime.createAccount(handle: handle, password: password, season: store.appData)
            case .signIn:
                result = await accountRuntime.signIn(handle: handle, password: password)
                if let restoredSeason = result.restoredSeason {
                    do {
                        let receipt = try store.importData(restoredSeason)
                        accountMessage = "\(result.message) \(receipt.userMessage)"
                        accountMessageIsError = false
                        return
                    } catch {
                        accountMessage = error.localizedDescription
                        accountMessageIsError = true
                        return
                    }
                }
            }
            accountMessage = result.message
            accountMessageIsError = accountRuntime.state.kind == .failed
        }
    }

}

enum AccountCredentialMode: Identifiable {
    case create
    case signIn

    var id: String {
        switch self {
        case .create: return "createAccount"
        case .signIn: return "signInAccount"
        }
    }

    var title: String {
        switch self {
        case .create: return "Create dev account"
        case .signIn: return "Sign in to dev account"
        }
    }

    var subtitle: String {
        switch self {
        case .create: return "Choose a handle and password. This device imports your current local season after the configured backend session opens."
        case .signIn: return "Enter the handle and password for this configured backend to load its saved season."
        }
    }

    var confirmTitle: String {
        switch self {
        case .create: return "Create account"
        case .signIn: return "Sign in"
        }
    }
}

private enum AccountSettingsAction: Identifiable {
    case export
    case signOut
    case delete

    var id: String {
        switch self {
        case .export: return "exportAccount"
        case .signOut: return "signOutAccount"
        case .delete: return "deleteAccount"
        }
    }

    var title: String {
        switch self {
        case .delete: return "Delete backend account?"
        default: return "Account action"
        }
    }

    var message: String {
        switch self {
        case .delete:
            return "This asks the backend to delete the account, revoke sessions, and remove account-owned backend data. Local season data on this device is not erased."
        default:
            return ""
        }
    }

    var confirmTitle: String {
        switch self {
        case .delete: return "Delete backend account"
        default: return "Continue"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .delete: return .destructive
        default: return nil
        }
    }
}

private enum SettingsDataAction: Identifiable {
    case resetDemo
    case clearSeason
    case setup

    var id: String {
        switch self {
        case .resetDemo: return "resetDemo"
        case .clearSeason: return "clearSeason"
        case .setup: return "setup"
        }
    }

    var title: String {
        switch self {
        case .resetDemo: return "Reset demo data?"
        case .clearSeason: return "Clear this season?"
        case .setup: return "Return to setup?"
        }
    }

    var message: String {
        switch self {
        case .resetDemo: return "This replaces local season data with the seeded CurlPlan demo."
        case .clearSeason: return "This removes local curlers, stops, spiels, and feed items while keeping your profile."
        case .setup: return "This shows first launch choices again. Your current data stays available unless you choose another setup path."
        }
    }

    var confirmTitle: String {
        switch self {
        case .resetDemo: return "Reset demo"
        case .clearSeason: return "Clear season"
        case .setup: return "Show setup"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .resetDemo, .clearSeason: return .destructive
        case .setup: return nil
        }
    }
}

struct AccountCredentialSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let mode: AccountCredentialMode
    let onSubmit: (String, String) -> Void
    @State private var handle: String
    @State private var password = ""
    @State private var errorMessage = ""

    init(mode: AccountCredentialMode,
         initialHandle: String = "",
         onSubmit: @escaping (String, String) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        _handle = State(initialValue: initialHandle)
    }

    private var trimmedHandle: String {
        handle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedHandle.isEmpty && password.count >= PasswordHasher.minimumLength
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            Text(mode.title)
                .font(.serif(24))
                .foregroundStyle(settings.ink)
            Text(mode.subtitle)
                .font(.grotesk(13))
                .foregroundStyle(settings.muted)
                .fixedSize(horizontal: false, vertical: true)

            credentialField(title: "Handle", placeholder: "your-handle") {
                TextField("your-handle", text: $handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .accessibilityIdentifier("curlplan.account.credential.handle")
            }
            credentialField(title: "Password", placeholder: "at least \(PasswordHasher.minimumLength) characters") {
                SecureField("at least \(PasswordHasher.minimumLength) characters", text: $password)
                    .accessibilityIdentifier("curlplan.account.credential.password")
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.grotesk(12, .semibold))
                    .foregroundStyle(settings.houseRed)
                    .accessibilityIdentifier("curlplan.account.credential.error")
            }

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("curlplan.account.credential.cancel")

                Button { submit() } label: {
                    Text(mode.confirmTitle)
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canSubmit ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityIdentifier("curlplan.account.credential.submit")
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    private func credentialField<Field: View>(title: String,
                                              placeholder: String,
                                              @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.mono(10, .medium))
                .tracking(0.6)
                .foregroundStyle(settings.muted)
            field()
                .font(.grotesk(15))
                .foregroundStyle(settings.ink)
                .padding(12)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
        }
    }

    private func submit() {
        guard canSubmit else {
            errorMessage = "Enter a handle and a password of at least \(PasswordHasher.minimumLength) characters."
            return
        }
        onSubmit(trimmedHandle, password)
        dismiss()
    }
}

struct SeasonImportSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    var onDone: ((MutationReceipt) -> Void)? = nil
    @State private var importText = ""
    @State private var errorMessage = ""

    init(title: String,
         subtitle: String,
         initialText: String = "",
         onDone: ((MutationReceipt) -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onDone = onDone
        _importText = State(initialValue: initialText)
    }

    private var canImport: Bool {
        !importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            Text(title)
                .font(.serif(24))
                .foregroundStyle(settings.ink)
            Text(subtitle)
                .font(.grotesk(13))
                .foregroundStyle(settings.muted)

            TextEditor(text: $importText)
                .font(.mono(11))
                .foregroundStyle(settings.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
                .accessibilityIdentifier("curlplan.import.json")

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.grotesk(12, .semibold))
                    .foregroundStyle(settings.houseRed)
                    .accessibilityIdentifier("curlplan.import.error")
            }

            HStack(spacing: 10) {
                Button { finish() } label: {
                    Text("Cancel")
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("curlplan.import.cancel")

                Button {
                    importText = UIPasteboard.general.string ?? ""
                    errorMessage = ""
                } label: {
                    Text("Paste")
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(settings.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("curlplan.import.paste")

                Button {
                    do {
                        let receipt = try store.importJSON(importText)
                        finish(receipt)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Text("Import")
                        .font(.grotesk(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canImport ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canImport)
                .accessibilityIdentifier("curlplan.import.confirm")
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    private func finish(_ receipt: MutationReceipt? = nil) {
        if let onDone, let receipt {
            onDone(receipt)
        } else {
            dismiss()
        }
    }
}
