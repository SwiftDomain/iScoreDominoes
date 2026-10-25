import Foundation
import Testing
@testable import iScore

struct TableModeTests {

    // MARK: - Score size (Review Focus 3)

    @Test func threeDigitsFitTheirHalf() {
        let half = CGSize(width: 400, height: 380)
        let size = DuoFont.tableScoreSize(forHalf: half, digits: 3)
        #expect(size <= 280)
        #expect(size <= 0.7 * 380)
        #expect(3 * 0.62 * size <= 400)
        #expect(size > 100)
    }

    @Test func moreDigitsMeanASmallerSize() {
        let half = CGSize(width: 400, height: 380)
        let three = DuoFont.tableScoreSize(forHalf: half, digits: 3)
        let four = DuoFont.tableScoreSize(forHalf: half, digits: 4)
        #expect(four < three)
        #expect(4 * 0.62 * four <= 400)
    }

    @Test func aTinyHalfNeverGoesNegative() {
        #expect(DuoFont.tableScoreSize(forHalf: CGSize(width: -10, height: 0), digits: 3) >= 0)
        #expect(DuoFont.tableScoreSize(forHalf: CGSize(width: 100, height: 100), digits: 0) >= 0)
    }

    // MARK: - Layout (Review Focus 2)

    @Test func landscapePutsTheHalvesSideBySide() {
        #expect(TableLayout.isSideBySide(CGSize(width: 900, height: 400)))
        #expect(!TableLayout.isSideBySide(CGSize(width: 400, height: 900)))
    }

    // MARK: - Session

    @Test func theSessionStartsFromTheSettingsDefault() {
        let name = "TableModeTests.session"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(!TableModeSession(defaults: defaults).isOn)
        defaults.set(true, forKey: TableModeSettings.defaultKey)
        #expect(TableModeSession(defaults: defaults).isOn)
    }

    // MARK: - VoiceOver (Review Focus 5)

    @Test func eachHalfReadsTeamScoreAndWhatIsLeft() {
        let game = makeTestGame(rows: demoGameRows)   // Ana & Luis 105, Rafa & Mia 45, to 200
        #expect(String(localized: game.tableCardLabel(for: .team1)) == "Ana & Luis, 105, 95 to win")
        #expect(localized(game.tableCardLabel(for: .team2), in: "es") == "Rafa & Mia, 45, faltan 155")
    }

    @Test func aTeamAtTheTargetHasWon() {
        let game = makeTestGame(maxScore: 100, rows: [[0, 0], [100, 0]])
        #expect(String(localized: game.tableCardLabel(for: .team1)) == "Ana & Luis, 100, won")
        #expect(localized(game.tableCardLabel(for: .team1), in: "es") == "Ana & Luis, 100, ganaron")
    }
}
