import Testing
@testable import iScore

struct LeaderboardTests {

    private func record(_ name: String, played: Int, won: Int) -> PlayerRecord {
        PlayerRecord(name: name, played: played, won: won)
    }

    @Test func winRate() {
        #expect(record("Ana", played: 12, won: 9).winRate == 0.75)
        #expect(record("Carlos", played: 0, won: 0).winRate == 0)
    }

    @Test func copy() {
        #expect(record("Ana", played: 12, won: 9).summary == "12 played · 75%")
        #expect(record("Luis", played: 3, won: 2).summary == "3 played · 67%")
        #expect(record("Carlos", played: 0, won: 0).summary == "No finished games yet")
        #expect(record("Ana", played: 12, won: 9).winsLabel == "9 wins")
        #expect(record("Eva", played: 7, won: 1).winsLabel == "1 win")
    }

    @Test func ranksByWinsThenWinRate() {
        let standings = Leaderboard.standings([
            record("Mia", played: 12, won: 5),
            record("Carlos", played: 0, won: 0),
            record("Ana", played: 12, won: 9),
            record("Rafa", played: 11, won: 5),
            record("Eva", played: 7, won: 0)
        ])
        #expect(standings.map(\.record.name) == ["Ana", "Rafa", "Mia", "Eva", "Carlos"])
        #expect(standings.map(\.rank) == [1, 2, 3, 4, 5])
    }

    @Test func tiesShareARank() {
        let standings = Leaderboard.standings([
            record("Luis", played: 4, won: 2),
            record("Ana", played: 4, won: 2),
            record("Mia", played: 4, won: 1)
        ])
        #expect(standings.map(\.record.name) == ["Ana", "Luis", "Mia"])
        #expect(standings.map(\.rank) == [1, 1, 3])
    }

    /// Never-played players sort last even against players with 0 wins.
    @Test func playersWithoutGamesComeLast() {
        let standings = Leaderboard.standings([
            record("Carlos", played: 0, won: 0),
            record("Eva", played: 3, won: 0)
        ])
        #expect(standings.map(\.record.name) == ["Eva", "Carlos"])
        #expect(standings.map(\.rank) == [1, 2])
    }

    @Test func podiumTakesTopThreeWithWins() {
        let standings = Leaderboard.standings([
            record("Ana", played: 12, won: 9),
            record("Luis", played: 12, won: 8),
            record("Rafa", played: 11, won: 5),
            record("Mia", played: 12, won: 5),
            record("Carlos", played: 0, won: 0)
        ])
        let split = Leaderboard.split(standings)
        #expect(split.podium.map(\.record.name) == ["Ana", "Luis", "Rafa"])
        #expect(split.rest.map(\.record.name) == ["Mia", "Carlos"])
    }

    @Test func podiumSkipsPlayersWithoutWins() {
        let standings = Leaderboard.standings([
            record("Ana", played: 2, won: 2),
            record("Eva", played: 2, won: 0),
            record("Carlos", played: 0, won: 0)
        ])
        let split = Leaderboard.split(standings)
        #expect(split.podium.map(\.record.name) == ["Ana"])
        #expect(split.rest.map(\.record.name) == ["Eva", "Carlos"])
    }

    @Test func emptyBoard() {
        let split = Leaderboard.split(Leaderboard.standings([]))
        #expect(split.podium.isEmpty)
        #expect(split.rest.isEmpty)
    }
}
