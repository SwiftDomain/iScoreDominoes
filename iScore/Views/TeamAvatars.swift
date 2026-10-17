//
//  TeamAvatars.swift
//  iScore
//
//  Overlapping initial circles for a team's players. Decorative: names are
//  always shown as text nearby, so VoiceOver skips these.
//

import SwiftUI

struct TeamAvatars: View {

    let names: [String]
    let palette: TeamPalette
    var size: CGFloat = 28

    private var shownNames: [String] {
        names.isEmpty ? [""] : Array(names.prefix(2))
    }

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(shownNames.enumerated()), id: \.offset) { index, name in
                Text(Game.initials(of: name))
                    .font(DuoFont.score(size * 0.42))
                    .foregroundStyle(Theme.surface)
                    .frame(width: size, height: size)
                    .background(index == 0 ? palette.fill : palette.edge, in: .circle)
                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

/// One player's initial circle. Defaults to the player's own stable color.
struct PlayerAvatar: View {

    let name: String
    var size: CGFloat = 36
    var fill: Color?

    var body: some View {
        Text(Game.initials(of: name))
            .font(DuoFont.score(size * 0.42))
            .foregroundStyle(Theme.surface)
            .frame(width: size, height: size)
            .background(fill ?? Theme.avatarColor(for: name), in: .circle)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        TeamAvatars(names: ["Ana", "Luis"], palette: Theme.palette(for: .team1))
        TeamAvatars(names: ["Rafa", "Mia"], palette: Theme.palette(for: .team2), size: 40)
        TeamAvatars(names: [], palette: Theme.palette(for: .team1))
    }
    .padding()
}
