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
