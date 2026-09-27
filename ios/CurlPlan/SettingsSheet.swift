import SwiftUI
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var backupOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(settings.line).frame(width: 38, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12).padding(.bottom, 14)

                Text("Appearance").font(.serif(24)).foregroundStyle(settings.ink)
                Text("Same season, your circle — tune the ice.")
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
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Accent: \(a.key)")
                            .accessibilityValue(settings.accentKey == a.key ? "Selected" : "Not selected")
                        }
                    }
                }

                settingRow(title: "Pebble texture", sub: "ICE GRAIN OVERLAY") {
                    Toggle("Pebble texture", isOn: Binding(get: { settings.pebble }, set: { settings.pebble = $0 }))
                        .labelsHidden()
                        .tint(settings.accent)
                }

                settingRow(title: "Account", sub: accountMeta) {
                    Button {
                        store.signOut()
                        dismiss()
                    } label: {
                        Text("Sign out")
                            .font(.grotesk(12, .bold)).foregroundStyle(settings.ink)
                            .padding(.horizontal, 14).padding(.vertical, 6.5)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(settings.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }

                Button("Backup and restore") { backupOpen = true }.frame(minHeight: 44)

                VStack(alignment: .leading, spacing: 8) {
                    Link("Open Classic calendar and game planner",
                         destination: URL(string: "https://davehomeassist.github.io/curl-plan/classic/")!)
                        .font(.grotesk(14, .semibold)).frame(minHeight: 44)
                        .accessibilityIdentifier("curlplan.classic.open")
                    Text("Opens in Safari. Classic keeps separate browser data; native demo records do not appear there automatically. Use Return to CurlPlan to come back.")
                        .font(.grotesk(13)).foregroundStyle(settings.muted)
                    Button("Close settings") { dismiss() }.frame(minHeight: 44)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $backupOpen) { BackupSheet() }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    // Canonical team identity: "{Club short} · {Skip}" (see terminology page).
  private var accountMeta: String {
    guard let u = store.currentUser() else { return "SIGNED OUT" }
    let team = clubShort(u.club) + " · " + u.name
    return "DEMO SESSION · " + team
  }
    private func clubShort(_ club: String) -> String {
        club.replacingOccurrences(of: #"\s+(Curling Club|CC)$"#, with: "", options: .regularExpression)
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

    private func seg(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.grotesk(12, .semibold))
                .foregroundStyle(on ? settings.onAccent : settings.ink)
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
}

// Versioned, app-specific backups. Public account credentials and preferences are excluded.
enum BackupError: LocalizedError {
    case invalid
    var errorDescription: String? { "This is not a supported CurlPlan iOS backup for the current account, or its records are invalid. Nothing was restored." }
}

struct LocalBackup: Codable {
    var format = "curlplan-ios"
    var version = 1
    let account: String
    var createdAt = Date()
    let state: AppState

    var summary: String {
        let visits = state.visits.values.reduce(0) { $0 + $1.count }
        let ice = state.iceReads.values.reduce(0) { $0 + $1.count }
        let reviews = state.reviews.values.reduce(0) { $0 + $1.count }
        let messages = state.threads.values.reduce(0) { $0 + $1.count }
        let drafts = state.postDrafts.count + state.reviewDrafts.count + state.messageDrafts.count
        return "\(state.posts.count) posts · \(visits) visits · \(ice) ice readings · \(reviews) reviews · \(messages) messages · \(drafts) drafts · \(state.addedSpiels.count) events · \(state.addedCurlers.count) curlers"
    }

    static func validate(_ data: Data, account: String) throws -> LocalBackup {
        guard data.count <= 5_000_000 else { throw BackupError.invalid }
        do {
            let backup = try JSONDecoder().decode(LocalBackup.self, from: data)
            guard backup.format == "curlplan-ios", backup.version == 1, backup.account == account else { throw BackupError.invalid }
            // AppState's normal decoder tolerates old local data. Restore must reject
            // anything it would drop, default, or silently coerce instead.
            let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
            let roundTrip = try JSONSerialization.jsonObject(with: JSONEncoder().encode(backup)) as? NSDictionary
            guard original == roundTrip else { throw BackupError.invalid }
            for post in backup.state.posts where post.kind == .result {
                guard let f = post.scoreFor, let a = post.scoreAgainst, f >= 0, a >= 0,
                      post.res == (f > a ? "WIN" : f < a ? "LOSS" : "TIE") else { throw BackupError.invalid }
            }
            for event in backup.state.addedSpiels where event.startAt != nil || event.endAt != nil {
                guard let start = event.startAt, let end = event.endAt, start.isFinite, end.isFinite, end > start,
                      let zone = event.timeZoneID, TimeZone(identifier: zone) != nil,
                      let kind = event.eventKind, ["League game", "Practice", "Bonspiel", "Event"].contains(kind) else { throw BackupError.invalid }
            }
            for reviews in backup.state.reviews.values {
                guard reviews.allSatisfy({ (1...5).contains($0.stars) }) else { throw BackupError.invalid }
            }
            guard Set(backup.state.posts.map(\.id)).count == backup.state.posts.count else { throw BackupError.invalid }
            return backup
        } catch { throw BackupError.invalid }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var document = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var candidate: Data?
    @State private var preview: LocalBackup?
    @State private var message = ""
    @State private var confirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Your device records") {
                    Text("Export a private JSON file containing your saved records and drafts. Keep it somewhere safe. This backup restores into CurlPlan iOS for the same account; web and Classic backups are separate.")
                    Button("Export backup") {
                        do { document = BackupDocument(data: try store.backupData()); exporting = true }
                        catch { message = error.localizedDescription }
                    }
                    Button("Choose backup to restore") { candidate = nil; preview = nil; message = ""; importing = true }
                    if let recovery = store.recoveryBackup {
                        Button("Preview previous device records") { inspect(recovery) }
                    }
                }
                if let preview {
                    Section("Restore preview") {
                        Text(preview.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Text(preview.summary)
                        Text("Restoring replaces the current device records, including drafts and messages. A recovery copy of the current records is kept on this device.")
                        Button("Replace device records", role: .destructive) { confirm = true }
                        Button("Cancel preview") { candidate = nil; self.preview = nil }
                    }
                }
                if !message.isEmpty { Section { Text(message).accessibilityIdentifier("curlplan.backup.message") } }
            }
            .navigationTitle("Backup and restore")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "CurlPlan iOS Backup") { result in
            switch result {
            case .success: message = "Backup exported."
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 5_000_000 else { throw BackupError.invalid }
                inspect(try Data(contentsOf: url))
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Replace device records?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Replace device records", role: .destructive) {
                do {
                    guard let candidate else { throw BackupError.invalid }
                    try store.restoreBackup(candidate)
                    self.candidate = nil; preview = nil
                    message = "Records restored. Previous records are available above."
                } catch { message = error.localizedDescription }
            }
            .accessibilityIdentifier("curlplan.backup.confirm")
            Button("Cancel", role: .cancel) {}
        }
    }

    private func inspect(_ data: Data) {
        candidate = nil; preview = nil; message = ""
        do { preview = try store.previewBackup(data); candidate = data }
        catch { message = error.localizedDescription }
    }
}
