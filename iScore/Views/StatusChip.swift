//
//  StatusChip.swift
//  iScore
//
//  IN PROGRESS / FINISHED / CANCELLED pill on game cards.
//

import SwiftUI

struct StatusChip: View {

    let state: GameState

    private var title: LocalizedStringResource {
        switch state {
        case .finished: "Finished"
        case .cancelled: "Cancelled"
        case .playing: "In progress"
        }
    }

    private var colors: (text: Color, fill: Color) {
        switch state {
        case .finished: (Theme.accentInk, Theme.teamAWash)
        case .playing: (Theme.teamBShadow, Theme.teamBWash)
        case .cancelled: (Theme.textSecondary, Theme.surfaceSecondary)
        }
    }

    var body: some View {
        Text(title)
            .duoLabel(colors.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colors.fill, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    VStack(spacing: 8) {
        StatusChip(state: .playing)
        StatusChip(state: .finished)
        StatusChip(state: .cancelled)
    }
}
