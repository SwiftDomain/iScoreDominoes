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

    /// With Increase Contrast on, the informational grays reach WCAG AA (4.5:1) on white.
    @Test(arguments: ["textSecondary", "textMuted"])
    func grayTextMeetsAAWithIncreasedContrast(_ name: String) throws {
        let color = try #require(UIColor(named: name))
        let highContrast = color.resolvedColor(with: UITraitCollection(accessibilityContrast: .high))
        #expect(contrastRatio(highContrast, .white) >= 4.5)
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

/// WCAG 2 contrast ratio between two opaque colors.
private func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
    let (a, b) = (relativeLuminance(first), relativeLuminance(second))
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

private func relativeLuminance(_ color: UIColor) -> Double {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func linear(_ channel: CGFloat) -> Double {
        let c = Double(channel)
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
}
