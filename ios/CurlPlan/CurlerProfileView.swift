import SwiftUI
import UIKit

struct CurlerProfileView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var profileNotice: String?
    let curlerID: String

    var body: some View {
        Group {
            if let profile = store.curlerProfile(curlerID) {
                VStack(spacing: 0) {
                    HStack {
                        CircleBackButton { dismiss() }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .cpReadableContent()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            identity(profile)
                            actions(profile)
                            stats(profile)
                            sharedRinks(profile)
                            recentForm(profile)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 96)
                        .cpReadableContent()
                    }
                }
                .background(settings.screen)
                .confirmationDialog("Remove \(profile.curler.name)?",
                                    isPresented: $showingDeleteConfirmation,
                                    titleVisibility: .visible) {
                    Button("Remove curler", role: .destructive) {
                        _ = store.deleteCurler(profile.curler.id)
                        dismiss()
                    }
                    .accessibilityIdentifier("curlplan.profile.confirmDelete")
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This removes the curler from roster, visits, results, attendance, and bonspiel team references.")
                }
            } else {
                settings.screen
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func identity(_ profile: CurlerProfileSummary) -> some View {
        let c = profile.curler
        return VStack(spacing: 9) {
            ZStack {
                Circle().fill(settings.screen)
                Circle().strokeBorder(settings.houseRed, lineWidth: 4)
                Circle().strokeBorder(settings.houseBlue, lineWidth: 4).padding(7)
                AvatarView(initials: c.initials, size: 78)
            }
            .frame(width: 92, height: 92)

            VStack(spacing: 5) {
                Text(c.name).font(.serif(30)).foregroundStyle(settings.ink)
                Text("\(c.role.uppercased()) · \(c.club.uppercased()) · \(c.prov)")
                    .font(.mono(11, .medium)).tracking(1).foregroundStyle(settings.muted)
            }

            HStack(spacing: 7) {
                Circle().fill(settings.accent).frame(width: 6, height: 6)
                Text(store.curlerConnectionLabel(c.id)).font(.grotesk(11, .semibold)).foregroundStyle(settings.accent)
            }
            .padding(.vertical, 5).padding(.horizontal, 12)
            .background(settings.panel)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private func actions(_ profile: CurlerProfileSummary) -> some View {
        let c = profile.curler
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { store.toggleFollow(c.id) } label: {
                    Text(c.following ? "Saved" : "Save local")
                        .font(.grotesk(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(settings.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("curlplan.profile.toggleFollow")

                ShareLink(item: profile.shareText) {
                    Text("Share")
                        .font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 11.5)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.ink, lineWidth: 1.5))
                }
                .accessibilityIdentifier("curlplan.profile.shareSystem")
            }

            Button {
                UIPasteboard.general.string = profile.shareText
                profileNotice = "Profile copied."
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Copy card")
                        .font(.grotesk(13, .bold))
                }
                .foregroundStyle(settings.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("curlplan.profile.copyShare")

            if let profileNotice {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profileNotice)
                        .font(.grotesk(12, .bold))
                        .foregroundStyle(settings.accent)
                        .accessibilityIdentifier("curlplan.profile.notice")
                    Text(profile.shareText)
                        .font(.grotesk(12))
                        .foregroundStyle(settings.muted)
                        .accessibilityIdentifier("curlplan.profile.shareText")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(settings.panel)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }

            Button {
                showingDeleteConfirmation = true
            } label: {
                Text("Remove from roster")
                    .font(.grotesk(13, .bold))
                    .foregroundStyle(settings.houseRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(settings.houseRed.opacity(0.6), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("curlplan.profile.delete")
        }
    }

    private func stats(_ profile: CurlerProfileSummary) -> some View {
        HStack(spacing: 0) {
            statCell(profile.record, "RECORD")
            VRule()
            statCell(profile.win, "WIN", accent: true)
            VRule()
            statCell("\(profile.rinks)", "RINKS")
            VRule()
            statCell("\(profile.mutual)", "MUTUAL")
        }
        .padding(.vertical, 14)
        .cpCard()
    }

    private func statCell(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.serif(24)).foregroundStyle(accent ? settings.accent : settings.ink)
            Text(label).font(.mono(9, .medium)).tracking(1).foregroundStyle(settings.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func sharedRinks(_ profile: CurlerProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Rinks you've both played")
            if profile.sharedRinks.isEmpty {
                EmptyStateView(title: "No shared rinks yet",
                               message: "Shared rink history appears after you log stops or games with this curler.",
                               systemImage: "house")
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(profile.sharedRinks.enumerated()), id: \.offset) { _, label in
                        let isMore = label.contains("more")
                        HStack(spacing: 6) {
                            if !isMore { HouseRing(size: 12) }
                            Text(label).font(.grotesk(12, .semibold))
                                .foregroundStyle(isMore ? settings.muted : settings.ink)
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, isMore ? 11 : 7)
                        .padding(.trailing, 11)
                        .overlay(Capsule().strokeBorder(settings.line, lineWidth: 1))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func recentForm(_ profile: CurlerProfileSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Recent form")
            if profile.recentForm.isEmpty {
                EmptyStateView(title: "No recent form yet",
                               message: "Game lines will appear after this curler is connected to logged results.",
                               systemImage: "chart.line.uptrend.xyaxis")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(profile.recentForm.enumerated()), id: \.element.id) { idx, g in
                        HStack(spacing: 10) {
                            Text(g.label).font(.grotesk(13, .semibold)).foregroundStyle(settings.ink)
                            Spacer()
                            Text(g.score).font(.serif(16)).foregroundStyle(settings.ink)
                            ResultBadge(res: g.res)
                        }
                        .padding(.vertical, 11).padding(.horizontal, 13)
                        if idx < profile.recentForm.count - 1 { Rectangle().fill(settings.line).frame(height: 1) }
                    }
                }
                .cpCard(radius: 14)
            }
        }
    }
}
