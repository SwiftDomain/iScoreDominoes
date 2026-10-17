import Foundation
import SwiftData
import Testing
@testable import iScore

struct VoiceSetupTests {

    @Test func opensByWhatSpeechCanDo() {
        #expect(VoiceSetup.opening(for: .ready) == .listen)
        #expect(VoiceSetup.opening(for: .needsPermission) == .askPermission)
        #expect(VoiceSetup.opening(for: .denied) == .typeInstead)
        #expect(VoiceSetup.opening(for: .unsupported) == .typeInstead)
    }

    @Test func everyBlockedStateExplainsItself() {
        let denied = VoiceSetup.explanation(availability: .denied, error: nil)
        let unsupported = VoiceSetup.explanation(availability: .unsupported, error: nil)
        #expect(denied != nil)
        #expect(unsupported != nil)
        #expect(denied != unsupported)
        #expect(VoiceSetup.explanation(availability: .ready, error: nil) == nil)
    }

    /// A thrown reason wins over a stale availability.
    @Test func thrownReasonWins() {
        let thrown = VoiceSetup.explanation(availability: .ready, error: SpeechCaptureError.unavailable(.denied))
        #expect(thrown == VoiceSetup.explanation(availability: .denied, error: nil))
    }

    @Test func otherFailuresQuoteTheirMessage() {
        struct Boom: LocalizedError { var errorDescription: String? { "mic busy" } }
        let text = VoiceSetup.explanation(availability: .ready, error: Boom())
        #expect(text?.contains("mic busy") == true)
    }

    @Test func flagsOnlyUnsavedNames() {
        var lineup = PlayerLineup()
        lineup.names = ["Ana", "carlos", "Luis", ""]
        #expect(VoiceSetup.newNames(in: lineup, known: ["Luis"], owner: "Ana") == ["carlos"])
        #expect(VoiceSetup.newNames(in: lineup, known: ["Luis", "Carlos"], owner: "Ana").isEmpty)
    }

    @Test func spokenSentenceFillsTheGame() async {
        let resolved = await VoiceSetup.resolve(
            "nine, two hundred, me and Carlos against Luis and Papo",
            locale: Locale(identifier: "en_US"),
            defaults: (.six, 20),
            known: ["Ana", "Luis"],
            owner: "Ana"
        )
        #expect(resolved.gameType == .nine)
        #expect(resolved.target == 200)
        #expect(resolved.lineup.names == ["Ana", "Carlos", "Luis", "Papo"])
        #expect(resolved.lineup.isComplete)
        #expect(resolved.newNames == ["Carlos", "Papo"])
    }
}

@MainActor
struct GameFactoryTests {

    @Test func buildsTheGameAndReusesSavedPlayers() throws {
        let container = try ModelContainer(
            for: Game.self, Player.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let ana = Player(name: "Ana")
        context.insert(ana)
        var lineup = PlayerLineup()
        lineup.names = ["ana", "Carlos", "Luis", "Papo"]
        let resolved = ResolvedGame(gameType: .nine, target: 200, lineup: lineup, newNames: [])

        let game = GameFactory.make(resolved, existing: [ana], in: context)

        #expect(game.gameType == .nine)
        #expect(game.maxScore == 200)
        #expect(game.team1 == ["ana", "Carlos"])
        #expect(game.team2 == ["Luis", "Papo"])
        #expect(game.players?.count == 4)
        #expect(game.players?.first === ana)
        #expect(try context.fetch(FetchDescriptor<Game>()).count == 1)
    }
}
