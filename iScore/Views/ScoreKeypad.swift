//
//  ScoreKeypad.swift
//  iScore
//
//  Big pressable number tiles for Add Score (replaces the system keyboard).
//

import SwiftUI

struct ScoreKeypad: View {

    @Binding var entry: ScoreEntry

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                key { Text("\(digit)") } action: { entry.append(digit) }
            }

            key {
                Text("Clear")
                    .font(DuoFont.label)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textMuted)
            } action: {
                entry.clear()
            }
            .accessibilityLabel("Clear")

            key { Text("0") } action: { entry.append(0) }

            key {
                Image(systemName: "delete.backward")
                    .foregroundStyle(Theme.textMuted)
            } action: {
                entry.deleteLast()
            }
            .accessibilityLabel("Delete")
        }
        .sensoryFeedback(.selection, trigger: entry)
    }

    private func key<Label: View>(
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            label()
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.duoKey)
    }
}

#Preview {
    @Previewable @State var entry = ScoreEntry()
    VStack(spacing: 16) {
        Text(entry.digits.isEmpty ? "0" : entry.digits)
            .font(DuoFont.score(52))
        ScoreKeypad(entry: $entry)
    }
    .padding()
}
