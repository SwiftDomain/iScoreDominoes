import SwiftUI
import Testing
@testable import iScore

struct DuoViewTests {

    /// Keys share the button shape (radius 14, 4pt drop), not the card's.
    @Test func keypadKeysUseButtonShape() {
        #expect(DuoCardStyle.duoKey.radius == 14)
        #expect(DuoCardStyle.duoKey.pressDrop == 4)

        #expect(DuoCardStyle.duoCard.radius == 16)
        #expect(DuoCardStyle.duoCard.pressDrop == 2)
    }

    @Test func toolbarIconsDimWhenDisabled() {
        #expect(GameView.toolbarIconColor(isEnabled: true) == Theme.textMuted)
        #expect(GameView.toolbarIconColor(isEnabled: false) == Theme.divider)
    }

    @Test func roundRowNamesTheScoringTeam() {
        let round = Round(id: 5, number: 5, team: .team1, points: 35)
        #expect(String(localized: RoundRow.spokenLabel(for: round, teamName: "Ana & Luis")) == "Round 5, Ana & Luis, 35 points")

        let single = Round(id: 1, number: 1, team: .team2, points: 1)
        #expect(String(localized: RoundRow.spokenLabel(for: single, teamName: "Rafa & Mia")) == "Round 1, Rafa & Mia, 1 point")
    }
}
