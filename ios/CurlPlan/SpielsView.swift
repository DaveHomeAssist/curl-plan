import SwiftUI

struct SpielsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Spiels").font(.serif(28)).foregroundStyle(settings.ink)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(settings.ink)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(settings.line, lineWidth: 1.5))
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: "Your season ahead")
                    ForEach(store.spiels) { sp in
                        SpielRow(spiel: sp)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
        }
        .background(settings.screen)
        .navigationBarHidden(true)
    }
}

private struct SpielRow: View {
    @EnvironmentObject var settings: AppSettings
    let spiel: Spiel

    var body: some View {
        let solid = spiel.status == "You're in"
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(spiel.whenText).font(.mono(10, .medium)).tracking(2).foregroundStyle(settings.muted)
                    Text(spiel.name).font(.serif(21)).foregroundStyle(settings.ink)
                    Text(spiel.whereText).font(.mono(11, .medium)).foregroundStyle(settings.muted).padding(.top, 2)
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
                AvatarStack(initials: spiel.going.map { _ in "" }, size: 28)
                Text("\(spiel.going.count) of your circle going")
                    .font(.mono(11, .medium)).foregroundStyle(settings.muted)
                Spacer()
                PillButton(title: "Details", filled: false)
            }
        }
        .padding(14)
        .cpCard()
    }
}
