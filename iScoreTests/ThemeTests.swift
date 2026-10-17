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
    @Test func gameCellSymbolColors() {
        #expect(GameCellView.symbolColor(isWinner: true, inProcess: false) == Theme.accentInk)
        #expect(GameCellView.symbolColor(isWinner: false, inProcess: true) == Theme.textSecondary)
        #expect(GameCellView.symbolColor(isWinner: false, inProcess: false) == Theme.textMuted)
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
