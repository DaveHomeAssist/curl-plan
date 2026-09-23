import SwiftUI

// Per-curler local message thread. Saved on device (parity with the web openThread /
// sendMessage flow) — a server-backed delivery layer can replace store.sendMessage later.
struct MessageThreadView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let curlerID: String
    @State private var draft = ""

    private var curler: Curler? { store.curler(curlerID) }
    private var messages: [Message] { store.thread(curlerID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(settings.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 14)

            Text(curler?.name ?? "Message").font(.serif(24)).foregroundStyle(settings.ink)
            Text("Local thread — saved on this device, not yet delivered.")
                .font(.grotesk(13)).foregroundStyle(settings.muted)
                .padding(.bottom, 14)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    if messages.isEmpty {
                        Text("No messages yet. Say hello to \(firstName).")
                            .font(.grotesk(14)).foregroundStyle(settings.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                    } else {
                        VStack(spacing: 9) {
                            ForEach(messages) { m in Bubble(message: m).id(m.id) }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onChange(of: messages.count) {
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 9) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .font(.grotesk(15)).foregroundStyle(settings.ink).tint(settings.accent)
                    .padding(.vertical, 10).padding(.horizontal, 13)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(settings.line, lineWidth: 1))
                Button { send() } label: {
                    Text("Send").font(.grotesk(12, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(canSend ? settings.accent : settings.muted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 22).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(settings.card)
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var firstName: String { curler?.name.split(separator: " ").first.map(String.init) ?? "them" }

    private func send() {
        store.sendMessage(curlerID, text: draft)
        draft = ""
    }
}

private struct Bubble: View {
    @EnvironmentObject var settings: AppSettings
    let message: Message
    var body: some View {
        let mine = message.from == "me"
        HStack {
            if mine { Spacer(minLength: 40) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.grotesk(15)).foregroundStyle(mine ? .white : settings.ink)
                Text(RelativeTime.clock(message.at))
                    .font(.mono(9, .medium)).tracking(0.5)
                    .foregroundStyle(mine ? Color.white.opacity(0.7) : settings.muted)
            }
            .padding(.vertical, 9).padding(.horizontal, 13)
            .background(mine ? settings.accent : settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }
}
