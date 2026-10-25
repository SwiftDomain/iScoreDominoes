//
//  PresetRow.swift
//  iScore
//
//  Home's saved setups: up to three cards, each one tap from a game.
//

import SwiftUI

struct PresetRow: View {

    let presets: [GamePreset]
    let onStart: (GamePreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your presets")
                .duoLabel()

            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        onStart(preset)
                    } label: {
                        PresetCard(setup: preset.setup)
                    }
                    .buttonStyle(.duoCard)
                    .accessibilityLabel(Text(preset.setup.accessibilityLabel))
                    .accessibilityHint(Text("Starts the game"))
                }
            }
        }
    }
}

private struct PresetCard: View {

    let setup: PresetSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(setup.name)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(setup.gameType.title) · \(setup.target)")
                .duoLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}
