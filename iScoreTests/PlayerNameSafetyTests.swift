import Foundation
import Testing
@testable import iScore

struct PlayerNameSafetyTests {

    /// Review Focus 3 — a player name containing format specifiers is shown
    /// literally. Names are data interpolated into a localized string, never
    /// a format string, so "%@ %d" must survive intact rather than consuming
    /// the arguments after it or crashing the formatter.
    @Test func aNameThatLooksLikeAFormatSpecifierIsShownLiterally() {
        let game = makeTestGame(
            rows: [[0, 0], [120, 0]],
            team1: ["%@ %d", "Ana"],
            team2: ["Luis", "Papo"]
        )
        #expect(game.displayName(for: .team1) == "%@ %d & Ana")
        #expect(String(localized: game.headline) == "%@ %d & Ana lead by 120")
        #expect(String(localized: game.progressLabel(for: .team1)) == "%@ %d & Ana progress")
    }

    /// A name made only of a percent sign is the nastiest case: a bare "%"
    /// is a truncated specifier.
    @Test func aBarePercentNameIsSafe() {
        let game = makeTestGame(team1: ["%", "Ana"], team2: ["Luis", "Papo"])
        #expect(game.displayName(for: .team1) == "% & Ana")
        #expect(String(localized: game.progressLabel(for: .team1)) == "% & Ana progress")
    }
}
