//
//  SheetHeader.swift
//  iScore
//
//  Top row of a Duo sheet: muted X on the left, an optional centered title
//  or uppercase label.
//

import SwiftUI

struct SheetHeader: View {

    var title: String?
    var label: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(DuoFont.title)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            } else if let label {
                Text(label)
                    .duoLabel()
            }

            HStack {
                Button("Close", systemImage: "xmark") {
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)

                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SheetHeader(title: "Settings")
        SheetHeader(label: "Team 2 · Player 2")
        SheetHeader()
    }
    .padding()
}
