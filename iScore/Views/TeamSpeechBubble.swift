//
//  TeamSpeechBubble.swift
//  iScore
//
//  The team "asking" a question on Add and Edit score: avatars on the left,
//  a flat card bubble on the right.
//

import SwiftUI

struct TeamSpeechBubble: View {

    let names: [String]
    let palette: TeamPalette
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TeamAvatars(names: names, palette: palette, size: 40)
                .padding(.top, 6)

            Text(text)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoCard(edge: 2)
        }
    }
}
