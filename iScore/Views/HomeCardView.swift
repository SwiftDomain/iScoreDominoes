//
//  HomeCardView.swift
//  iScore
//
//  Content of a Home feature tile. The grid wraps it in a link or button
//  styled `.duoCard`, which draws the pressable card around it.
//

import SwiftUI

struct HomeCardView: View {

    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.surface)
                .frame(width: 40, height: 40)
                .background(tint, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textPrimary)

                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

#Preview {
    HStack(spacing: 10) {
        Button {} label: {
            HomeCardView(icon: "plus", title: "New game", subtitle: "Start playing", tint: Theme.teamA)
        }
        Button {} label: {
            HomeCardView(icon: "trophy.fill", title: "Hall of fame", subtitle: "Top players", tint: Theme.gold)
        }
    }
    .buttonStyle(.duoCard)
    .padding()
}
