import Foundation
import Testing
@testable import iScore

/// Home's "Your stats" are the stats of the player set as "That's me" in
/// Settings — counted the way Hall of Fame counts them — or nothing at all.
struct OwnerStatsTests {

    private let ana = makeTestGame(maxScore: 100, rows: [[0, 0], [100, 0]], state: .finished)   // Ana & Luis win
    private let rafa = makeTestGame(maxScore: 100, rows: [[0, 0], [0, 100]], state: .finished)  // Rafa & Mia win

    /// The bug: with nobody set, every finished game counted as a win.
    @Test func withoutThatsMeThereAreNoStats() {
        #expect(OwnerStats.compute(owner: nil, games: [ana, rafa]) == nil)
    }

    @Test func winsAreTheOwnersTeamWinning() {
        let stats = OwnerStats.compute(owner: "Ana", games: [ana, rafa])
        #expect(stats == OwnerStats(played: 2, won: 1))
        #expect(stats?.winPercentage == 50)
    }

    @Test func gamesTheOwnerDidNotPlayDoNotCount() {
        let others = makeTestGame(maxScore: 100, rows: [[0, 0], [100, 0]],
                                  team1: ["Tito", "Eva"], team2: ["Rafa", "Mia"], state: .finished)
        #expect(OwnerStats.compute(owner: "Ana", games: [ana, others]) == OwnerStats(played: 1, won: 1))
    }

    @Test func aGameInProgressDoesNotCount() {
        let playing = makeTestGame(rows: demoGameRows)
        #expect(OwnerStats.compute(owner: "Ana", games: [playing]) == OwnerStats(played: 0, won: 0))
    }

    @Test func noGamesYetIsZeroPercentNotAnError() {
        #expect(OwnerStats.compute(owner: "Ana", games: [])?.winPercentage == 0)
    }

    /// The stored name may differ in case or accents from how it was seated.
    @Test func theOwnersNameMatchesWhateverItsCase() {
        #expect(OwnerStats.compute(owner: "ána", games: [ana]) == OwnerStats(played: 1, won: 1))
    }
}
