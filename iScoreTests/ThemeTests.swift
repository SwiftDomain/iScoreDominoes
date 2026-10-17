import SwiftUI
import Testing
import UIKit
@testable import iScore

struct ThemeTests {

    @Test(arguments: Theme.colorAssetNames)
    func colorAssetExists(_ name: String) {
        #expect(UIColor(named: name) != nil, "No colorset named \(name) in Assets.xcassets")
    }

    @Test func colorAssetNamesAreComplete() {
        #expect(Theme.colorAssetNames.count == 24)
        #expect(Set(Theme.colorAssetNames).count == 24)
    }

    /// Red (`danger`) is for destructive actions only; a lost or cancelled
    /// game in All Games must read as muted, not as an error.
    @Test func gameListScoreColors() {
        #expect(GameListCard.scoreColor(for: .won) == Theme.textPrimary)
        #expect(GameListCard.scoreColor(for: .playing) == Theme.textPrimary)
        #expect(GameListCard.scoreColor(for: .lost) == Theme.textMuted)
        #expect(GameListCard.scoreColor(for: .cancelled) == Theme.textMuted)
    }

    @Test func medals() {
        #expect(Theme.medal(forRank: 1)?.fill == Theme.gold)
        #expect(Theme.medal(forRank: 1)?.edge == Theme.goldShadow)
        #expect(Theme.medal(forRank: 2)?.fill == Theme.textMuted)
        #expect(Theme.medal(forRank: 3)?.fill == Theme.streak)
        #expect(Theme.medal(forRank: 4) == nil)
    }

    /// Avatar colors are stable per name (no `hashValue`, which changes every launch).
    @Test func avatarColors() {
        #expect(Theme.avatarColor(for: "Ana") == Theme.teamA)
        #expect(Theme.avatarColor(for: " ana ") == Theme.teamA)
        #expect(Theme.avatarColor(for: "Luis") == Theme.teamB)
        #expect(Theme.avatarColors.contains(Theme.avatarColor(for: "Mia")))
        #expect(Theme.avatarColor(for: "") == Theme.teamA)
    }

    @Test func teamPalettes() {
        let team1 = Theme.palette(for: .team1)
        #expect(team1.fill == Theme.teamA)
        #expect(team1.edge == Theme.teamAShadow)
        #expect(team1.wash == Theme.teamAWash)

        let team2 = Theme.palette(for: .team2)
        #expect(team2.fill == Theme.teamB)
        #expect(team2.edge == Theme.teamBShadow)
        #expect(team2.wash == Theme.teamBWash)

        let neutral = Theme.palette(for: .none)
        #expect(neutral.fill == Theme.textMuted)
        #expect(neutral.edge == Theme.textSecondary)
        #expect(neutral.wash == Theme.surfaceSecondary)
    }
}
