//
//  ScoreWell.swift
//  iScore
//
//  The big number display above the keypad on Add and Edit score. Shows a
//  muted "0" when empty; the border turns the team color once a digit is in.
//

import SwiftUI

struct ScoreWell: View {

    let entry: ScoreEntry
    let palette: TeamPalette
    let accessibilityLabel: String

    var body: some View {
        Text(entry.digits.isEmpty ? "0" : entry.digits)
            .font(DuoFont.score(52))
            .foregroundStyle(entry.value == nil ? Theme.textMuted : Theme.textPrimary)
            .contentTransition(.numericText())
            .animation(.snappy, value: entry)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(entry.value == nil ? Theme.divider : palette.fill, lineWidth: 2)
            )
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(entry.digits.isEmpty ? "None" : entry.digits)
    }
}
