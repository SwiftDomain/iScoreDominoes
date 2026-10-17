//
//  SummaryStatTile.swift
//  iScore
//
//  A "lesson complete" stat on Game Summary: colored frame with a white
//  uppercase label on top, the value on a white inner card.
//

import SwiftUI

struct SummaryStatTile: View {

    let label: String
    let value: String
    let palette: TeamPalette

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .duoLabel(Theme.surface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 4)

            Text(value)
                .font(DuoFont.score(20))
                .foregroundStyle(palette.edge)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background(Theme.surface, in: .rect(cornerRadius: 14))
        }
        .padding([.horizontal, .bottom], 2)
        .background(palette.fill, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    HStack(spacing: 8) {
        SummaryStatTile(label: "Final", value: "200–145", palette: TeamPalette(fill: Theme.gold, edge: Theme.goldShadow, wash: Theme.surfaceSecondary))
        SummaryStatTile(label: "Rounds", value: "6", palette: TeamPalette(fill: Theme.learn, edge: Theme.learnShadow, wash: Theme.surfaceSecondary))
        SummaryStatTile(label: "Won by", value: "55", palette: TeamPalette(fill: Theme.streak, edge: Theme.streakShadow, wash: Theme.surfaceSecondary))
    }
    .padding()
}
