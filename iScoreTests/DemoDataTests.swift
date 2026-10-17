import SwiftData
import Testing
@testable import iScore

@MainActor
struct DemoDataTests {

    private func seeded() throws -> (ModelContainer, Game) {
        let container = try ModelContainer(
            for: Game.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, DemoData.seed(into: container.mainContext))
    }

    @Test func seedsOneActiveGameAmongFinishedAndCancelled() throws {
        let (container, active) = try seeded()

        let games = try container.mainContext.fetch(FetchDescriptor<Game>())
        #expect(games.count == 5)
        #expect(games.filter(\.inProcess).count == 1)
        #expect(games.filter { $0.state == .finished }.count == 3)
        #expect(games.filter { $0.state == .cancelled }.count == 1)
        #expect(active.inProcess)
        #expect(active.total(for: .team1) == 105)
        #expect(active.total(for: .team2) == 45)
    }

    /// Hall of Fame, Settings and the player picker need real Player records.
    @Test func seedsPlayersLinkedToTheirGames() throws {
        let (container, _) = try seeded()

        let players = try container.mainContext.fetch(FetchDescriptor<Player>())
        #expect(players.count == 7)

        let standings = Leaderboard.standings(players.map(PlayerRecord.init))
        #expect(standings.map(\.record.name) == ["Ana", "Mia", "Luis", "Rafa", "Eva", "Tito", "Carlos"])
        #expect(Leaderboard.split(standings).podium.count == 3)
    }
}
