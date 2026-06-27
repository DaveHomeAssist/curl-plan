import SwiftUI

struct SpielsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingNew = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spiels").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
                Button { showingNew = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(settings.ink)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add spiel")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .cpReadableContent()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your season ahead")
                    if store.spiels.isEmpty {
                        EmptyStateView(title: "No spiels yet",
                                       message: "Add a bonspiel to start planning the season ahead.",
                                       systemImage: "calendar.badge.plus",
                                       actionTitle: "New spiel") {
                            showingNew = true
                        }
                    } else {
                        ForEach(store.spiels) { sp in
                            SpielRow(spiel: sp)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
                .cpReadableContent()
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNew) { NewSpielSheet() }
    }
}

struct NewSpielSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var location = ""
    @State private var dates = ""
    @State private var status = "You're in"
    @State private var discipline = CurlingDiscipline.fourPlayer.label

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        CreateScaffold(title: "New spiel",
                       subtitle: "Add a bonspiel to your season ahead.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           store.addSpiel(name: name.trimmingCharacters(in: .whitespaces),
                                          whereText: location.trimmingCharacters(in: .whitespaces),
                                          whenText: dates.trimmingCharacters(in: .whitespaces).uppercased(),
                                          status: status,
                                          discipline: CurlingDiscipline.fromLabel(discipline))
                           dismiss()
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Brier Patch Open")
            CPField(label: "Location", text: $location, placeholder: "Kamloops, BC")
            CPField(label: "Dates", text: $dates, placeholder: "FEB 14–16")
            CPChips(label: "Your status", options: ["You're in", "Watching", "Invite"], selection: $status)
            CPChips(label: "Discipline", options: CurlingDiscipline.allCases.map(\.label), selection: $discipline)
        }
    }
}

private struct SpielRow: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var showingDetail = false
    let spiel: Spiel

    var body: some View {
        let solid = spiel.status == "You're in"
        let bonspiel = store.bonspiel(for: spiel.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                    Text(spiel.name).font(.serif(21)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted).padding(.top, 2)
                    if let bonspiel {
                        Text("\(bonspiel.discipline.label.uppercased()) · \(bonspiel.rulesProfile.scheduledEnds) ENDS · LINEUP LOCK \(bonspiel.rosterPolicy.lockMinutesBeforeGame) MIN")
                            .font(.mono(9, .medium))
                            .tracking(1)
                            .foregroundStyle(settings.muted)
                            .padding(.top, 3)
                    }
                }
                Spacer()
                Text(spiel.status)
                    .font(solid ? .mono(9, .bold) : .grotesk(11, .semibold))
                    .tracking(solid ? 1 : 0)
                    .foregroundStyle(solid ? .white : settings.muted)
                    .padding(.vertical, solid ? 4 : 5)
                    .padding(.horizontal, solid ? 8 : 10)
                    .background(solid ? settings.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: solid ? 6 : 99, style: .continuous)
                            .strokeBorder(solid ? Color.clear : settings.line, lineWidth: 1)
                    )
            }

            HStack(spacing: 11) {
                let attendeeIDs = store.attendeeIDs(for: spiel.id)
                AvatarStack(initials: store.initials(for: attendeeIDs, limit: 4), size: 28, plus: store.plusLabel(for: attendeeIDs, visible: 4))
                Text("\(attendeeIDs.count) attending")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                PillButton(title: "Details", filled: false) { showingDetail = true }
                    .accessibilityIdentifier("curlplan.spiel.details.\(spiel.id)")
            }
        }
        .padding(14)
        .cpCard()
        .sheet(isPresented: $showingDetail) { SpielDetailSheet(spielID: spiel.id) }
    }
}

struct SpielDetailSheet: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let spielID: String

    private let statuses = ["You're in", "Watching", "Invite"]

    var body: some View {
        Group {
            if let spiel = store.spiels.first(where: { $0.id == spielID }) {
                VStack(alignment: .leading, spacing: 0) {
                    Capsule().fill(settings.line).frame(width: 38, height: 4)
                        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                            Text(spiel.name).font(.serif(26)).foregroundStyle(settings.ink)
                            Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted)
                                .padding(.top, -10)

                            Text("YOUR STATUS").font(.mono(10, .medium)).tracking(1.5)
                                .foregroundStyle(settings.muted).padding(.bottom, -8)
                            HStack(spacing: 8) {
                                ForEach(statuses, id: \.self) { opt in
                                    let on = spiel.status == opt
                                    Button { store.setSpielStatus(spiel.id, opt) } label: {
                                        Text(opt).font(.grotesk(12, .semibold))
                                            .foregroundStyle(on ? .white : settings.ink)
                                            .padding(.vertical, 9).padding(.horizontal, 14)
                                            .background(on ? settings.accent : settings.panel)
                                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .strokeBorder(on ? Color.clear : settings.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer(minLength: 0)
                            }

                            if let bonspiel = store.bonspiel(for: spiel.id) {
                                BonspielSummaryCard(record: bonspiel)
                                BonspielRosterCard(record: bonspiel)
                                BonspielGamesCard(record: bonspiel)
                            }

                            let attendeeIDs = store.attendeeIDs(for: spiel.id)
                            Text("\(attendeeIDs.count) ATTENDING").font(.mono(10, .medium))
                                .tracking(1.5).foregroundStyle(settings.muted)
                            if attendeeIDs.isEmpty {
                                Text("No attendance recorded yet.")
                                    .font(.grotesk(13)).foregroundStyle(settings.muted)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(attendeeIDs, id: \.self) { id in
                                        if id == "me" {
                                            HStack(spacing: 11) {
                                                AvatarView(initials: store.me.initials, size: 36)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(store.me.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                                                    Text("YOU")
                                                        .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                                }
                                                Spacer()
                                            }
                                        } else if let c = store.curler(id) {
                                            HStack(spacing: 11) {
                                                AvatarView(initials: c.initials, size: 36)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(c.name).font(.grotesk(14, .bold)).foregroundStyle(settings.ink)
                                                    Text("\(c.role.uppercased()) · \(c.club.uppercased())")
                                                        .font(.mono(10, .medium)).foregroundStyle(settings.muted)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    }

                    Button { dismiss() } label: {
                        Text("Done").font(.grotesk(14, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(settings.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(settings.card)
            } else {
                settings.card
            }
        }
    }
}

private struct BonspielSummaryCard: View {
    @EnvironmentObject var settings: AppSettings
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bonspiel record")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric("Discipline", record.discipline.label)
                metric("Rules", record.rulesProfile.rulebookRef)
                metric("Ends", "\(record.rulesProfile.scheduledEnds)")
                metric("Timezone", record.timezone)
            }
            Text("\(record.venue.name) · \(record.venue.display)")
                .font(.grotesk(13, .semibold))
                .foregroundStyle(settings.ink)
            Text("Roster fields: \(record.privacyPolicy.rosterDisplayFields.joined(separator: ", "))")
                .font(.mono(10, .medium))
                .foregroundStyle(settings.muted)
        }
        .padding(14)
        .cpCard(radius: 16)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.mono(9, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
            Text(value)
                .font(.grotesk(13, .bold))
                .foregroundStyle(settings.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(settings.panel)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct BonspielRosterCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var addingToTeam: BonspielTeam?
    @State private var actionMessage: String?
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Roster policy", action: "\(record.rosterPolicy.lockMinutesBeforeGame) min lock")
            HStack(spacing: 8) {
                rosterPill("\(record.rosterPolicy.maxPlayersOnIce) on ice")
                rosterPill(record.rosterPolicy.allowAlternates ? "Alternates" : "No alternates")
                rosterPill(record.rosterPolicy.allowSpares ? "Spares" : "No spares")
            }
            .fixedSize(horizontal: false, vertical: true)
            if record.teams.isEmpty {
                Text("No team roster captured yet.")
                    .font(.grotesk(13))
                    .foregroundStyle(settings.muted)
            } else {
                ForEach(record.teams.prefix(2)) { team in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(team.displayName)
                                .font(.grotesk(14, .bold))
                                .foregroundStyle(settings.ink)
                            Spacer()
                            Button {
                                addingToTeam = team
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(settings.accent)
                                    .frame(width: 28, height: 28)
                                    .background(settings.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add member to \(team.displayName)")
                            .accessibilityIdentifier("curlplan.bonspiel.roster.add.\(team.id)")
                        }
                        ForEach(team.members) { member in
                            HStack {
                                Text(member.declaredPosition)
                                    .font(.mono(9, .medium))
                                    .foregroundStyle(settings.muted)
                                    .frame(width: 48, alignment: .leading)
                                Text(member.displayName)
                                    .font(.grotesk(12, .semibold))
                                    .foregroundStyle(settings.ink)
                                Spacer()
                                Text(member.rosterStatus.uppercased())
                                    .font(.mono(8, .bold))
                                    .foregroundStyle(settings.muted)
                                Button {
                                    actionMessage = store.removeBonspielTeamMember(bonspielID: record.id,
                                                                                   teamID: team.id,
                                                                                   memberID: member.id).userMessage
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(settings.houseRed)
                                        .frame(width: 26, height: 26)
                                        .background(settings.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(member.displayName)")
                                .accessibilityIdentifier("curlplan.bonspiel.roster.remove.\(member.id)")
                            }
                        }
                    }
                    .padding(10)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if let actionMessage {
                Text(actionMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("curlplan.bonspiel.roster.message")
            }
        }
        .padding(14)
        .cpCard(radius: 16)
        .sheet(item: $addingToTeam) { team in
            BonspielTeamMemberSheet(recordID: record.id, teamID: team.id) { receipt in
                actionMessage = receipt.userMessage
            }
        }
    }

    private func rosterPill(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.mono(9, .medium))
            .tracking(0.8)
            .foregroundStyle(settings.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(settings.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct BonspielTeamMemberSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let recordID: String
    let teamID: String
    let onReceipt: (MutationReceipt) -> Void
    @State private var name = ""
    @State private var position = "Lead"
    @State private var status = "active"
    @State private var role = "player"

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        CreateScaffold(title: "Team member",
                       subtitle: "Add a local roster member for this bonspiel team.",
                       canSave: canSave,
                       onCancel: { dismiss() },
                       onSave: {
                           let receipt = store.addBonspielTeamMember(bonspielID: recordID,
                                                                      teamID: teamID,
                                                                      displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                                      role: role,
                                                                      rosterStatus: status,
                                                                      declaredPosition: position)
                           onReceipt(receipt)
                           dismiss()
                       }) {
            CPField(label: "Name", text: $name, placeholder: "Lineup Spare")
            CPChips(label: "Position", options: ["Lead", "Second", "Third", "Fourth", "Alternate"], selection: $position)
            CPChips(label: "Status", options: ["active", "alternate", "spare"], selection: $status)
            CPField(label: "Role", text: $role, placeholder: "player")
        }
    }
}

private struct BonspielGamesCard: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @State private var actionMessage: String?
    let record: BonspielRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Game snapshots", action: "\(record.games.count) game\(record.games.count == 1 ? "" : "s")")
            if record.games.isEmpty {
                Text("No game snapshots captured yet.")
                    .font(.grotesk(13))
                    .foregroundStyle(settings.muted)
            } else {
                ForEach(record.games.prefix(3)) { game in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(game.drawLabel) · \(game.sheet)")
                                    .font(.mono(10, .medium))
                                    .tracking(1)
                                    .foregroundStyle(settings.muted)
                                Text("\(record.teamName(game.teamAID)) vs \(record.teamName(game.teamBID))")
                                    .font(.grotesk(14, .bold))
                                    .foregroundStyle(settings.ink)
                            }
                            Spacer()
                            Text(game.scoreLabel)
                                .font(.serif(20))
                                .foregroundStyle(settings.ink)
                                .accessibilityIdentifier("curlplan.bonspiel.\(game.id).score")
                        }
                        HStack(spacing: 5) {
                            ForEach(game.ends) { end in
                                VStack(spacing: 3) {
                                    Text("\(end.endNumber)")
                                        .font(.mono(8, .medium))
                                        .foregroundStyle(settings.muted)
                                    Text(end.isBlank ? "0" : "\(max(end.teamA, end.teamB))")
                                        .font(.mono(10, .bold))
                                        .foregroundStyle(end.isBlank ? settings.muted : settings.ink)
                                }
                                .frame(width: 26, height: 34)
                                .background(settings.card)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                        Text("LSFE: \(record.teamName(game.lsfeOrPlacementDecision.teamID)) · \(game.status.label)")
                            .font(.mono(10, .medium))
                            .foregroundStyle(settings.muted)
                            .accessibilityIdentifier("curlplan.bonspiel.\(game.id).status")
                        ForEach(game.gameLineups.prefix(2)) { lineup in
                            Text("\(record.teamName(lineup.teamID)): \(record.lineupNames(lineup).joined(separator: ", "))")
                                .font(.grotesk(11, .semibold))
                                .foregroundStyle(settings.muted)
                                .lineLimit(2)
                        }
                        gameControls(game)
                    }
                    .padding(11)
                    .background(settings.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if let actionMessage {
                Text(actionMessage)
                    .font(.mono(10, .medium))
                    .foregroundStyle(settings.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("curlplan.bonspiel.games.message")
            }
        }
        .padding(14)
        .cpCard(radius: 16)
    }

    private func gameControls(_ game: BonspielGame) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text(store.scorecardValidationMessage(bonspielID: record.id, gameID: game.id) ?? "Scorecard can be locally confirmed.")
                .font(.mono(9, .medium))
                .foregroundStyle(game.scoreAgreement.confirmed ? settings.accent : settings.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("curlplan.bonspiel.\(game.id).validation")

            lineupControls(game)

            if !game.scoreAgreement.confirmed {
                HStack(spacing: 6) {
                    gameActionButton("A +1", id: "curlplan.bonspiel.\(game.id).scoreA") {
                        recordNextEnd(game, teamA: 1, teamB: 0, isBlank: false)
                    }
                    gameActionButton("Blank", id: "curlplan.bonspiel.\(game.id).blank") {
                        recordNextEnd(game, teamA: 0, teamB: 0, isBlank: true)
                    }
                    gameActionButton("B +1", id: "curlplan.bonspiel.\(game.id).scoreB") {
                        recordNextEnd(game, teamA: 0, teamB: 1, isBlank: false)
                    }
                }

                HStack(spacing: 6) {
                    gameActionButton("Concede", id: "curlplan.bonspiel.\(game.id).concede") {
                        actionMessage = store.setBonspielResultFlags(bonspielID: record.id,
                                                                      gameID: game.id,
                                                                      conceded: true,
                                                                      forfeited: false).userMessage
                    }
                    gameActionButton("Forfeit", id: "curlplan.bonspiel.\(game.id).forfeit") {
                        actionMessage = store.setBonspielResultFlags(bonspielID: record.id,
                                                                      gameID: game.id,
                                                                      conceded: false,
                                                                      forfeited: true).userMessage
                    }
                    gameActionButton("Confirm", id: "curlplan.bonspiel.\(game.id).confirm") {
                        actionMessage = store.confirmBonspielGameResult(bonspielID: record.id, gameID: game.id).userMessage
                    }
                }
            } else {
                Text("Local result confirmed")
                    .font(.mono(10, .bold))
                    .foregroundStyle(settings.accent)
            }
        }
    }

    private func lineupControls(_ game: BonspielGame) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCAL LINEUP")
                .font(.mono(9, .medium))
                .tracking(1)
                .foregroundStyle(settings.muted)
            if store.lineupIsLocked(bonspielID: record.id, gameID: game.id) {
                HStack(spacing: 6) {
                    gameActionButton("Try A lineup", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID)
                    }
                    gameActionButton("Try B lineup", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamBID)") {
                        submitDefaultLineup(game, teamID: game.teamBID)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    gameActionButton("Invalid A", id: "curlplan.bonspiel.\(game.id).invalid.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID, invalid: true)
                    }
                    gameActionButton("Submit A", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamAID)") {
                        submitDefaultLineup(game, teamID: game.teamAID)
                    }
                }
                HStack(spacing: 6) {
                    gameActionButton("Submit B", id: "curlplan.bonspiel.\(game.id).submit.\(game.teamBID)") {
                        submitDefaultLineup(game, teamID: game.teamBID)
                    }
                    gameActionButton("Lock lineup", id: "curlplan.bonspiel.\(game.id).lockLineup") {
                        actionMessage = store.lockBonspielLineup(bonspielID: record.id, gameID: game.id).userMessage
                    }
                }
            }
        }
    }

    private func gameActionButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mono(9, .bold))
                .foregroundStyle(settings.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(settings.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(settings.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func submitDefaultLineup(_ game: BonspielGame, teamID: String, invalid: Bool = false) {
        guard let team = record.teams.first(where: { $0.id == teamID }) else {
            actionMessage = "Bonspiel team not found."
            return
        }
        let required = record.rosterPolicy.maxPlayersOnIce
        let count = invalid ? max(required - 1, 0) : required
        let positions = ["Lead", "Second", "Third", "Fourth", "Fifth"]
        let members = Array(team.members.prefix(count))
        let slots = members.enumerated().map { index, member in
            BonspielLineupSlot(memberID: member.id,
                               position: positions[min(index, positions.count - 1)],
                               isSkip: index == members.count - 1,
                               isViceSkip: members.count > 1 && index == members.count - 2)
        }
        actionMessage = store.submitBonspielLineup(bonspielID: record.id,
                                                   gameID: game.id,
                                                   teamID: teamID,
                                                   slots: slots).userMessage
    }

    private func recordNextEnd(_ game: BonspielGame, teamA: Int, teamB: Int, isBlank: Bool) {
        let nextEnd = (game.ends.map(\.endNumber).max() ?? 0) + 1
        let receipt = store.recordBonspielEndScore(bonspielID: record.id,
                                                   gameID: game.id,
                                                   endNumber: nextEnd,
                                                   teamA: teamA,
                                                   teamB: teamB,
                                                   isBlank: isBlank,
                                                   isExtraEnd: nextEnd > game.scheduledEnds)
        actionMessage = receipt.userMessage
    }
}
