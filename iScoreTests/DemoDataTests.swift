import SwiftData
import Testing
@testable import iScore

@MainActor
struct DemoDataTests {

    @Test func seedsThreeGamesWithOneActive() throws {
        let container = try ModelContainer(
            for: Game.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let active = DemoData.seed(into: container.mainContext)

        let games = try container.mainContext.fetch(FetchDescriptor<Game>())
        #expect(games.count == 3)
        #expect(games.filter(\.inProcess).count == 1)
        #expect(active.inProcess)
        #expect(active.total(for: .team1) == 105)
        #expect(active.total(for: .team2) == 45)
    }
}
