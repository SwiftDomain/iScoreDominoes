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

    // MARK: - Final review fixes

    /// Critical #1: a finished or cancelled game never shows the table halves,
    /// so nobody can add a round to a settled game by tapping one.
    @Test func theTableShowsOnlyWhileTheGameIsPlayed() {
        #expect(TableModeRules.isShown(sessionOn: true, state: .playing))
        #expect(!TableModeRules.isShown(sessionOn: true, state: .finished))
        #expect(!TableModeRules.isShown(sessionOn: true, state: .cancelled))
        #expect(!TableModeRules.isShown(sessionOn: false, state: .playing))
    }

    /// #2: changing the Settings default applies tonight, not after a relaunch.
    @Test func theSessionFollowsTheSettingsDefaultWhenItChanges() {
        let name = "TableModeTests.follow"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let session = TableModeSession(defaults: defaults)
        session.followDefault(true)
        #expect(session.isOn)
        session.followDefault(false)
        #expect(!session.isOn)
    }

    /// #3: the mic lives in the center strip; a spoken answer outranks the
    /// mic's own line, and either outranks the round line.
    @Test func theStripShowsTheAnswerThenTheMicThenTheRound() {
        #expect(TableModeRules.stripLine(answer: "Ana & Luis lead by 60", mic: "Listening…") == "Ana & Luis lead by 60")
        #expect(TableModeRules.stripLine(answer: nil, mic: "Listening…") == "Listening…")
        #expect(TableModeRules.stripLine(answer: nil, mic: nil) == nil)
    }

    /// A number heard with no team waits for a half to be tapped: the tap
    /// records it for that team instead of opening the keypad.
    @Test func aHeardNumberIsFinishedByTappingAHalf() {
        #expect(TableModeRules.tap(.team2, pending: 25) == .record(points: 25, team: .team2))
        #expect(TableModeRules.tap(.team1, pending: nil) == .openKeypad(.team1))
    }
}
