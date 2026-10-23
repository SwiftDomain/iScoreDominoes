import Foundation
import Testing
@testable import iScore

struct GameVoiceTests {

    @Test func winningAnswerNamesTheLeaderAndTheLead() {
        let game = makeTestGame(rows: demoGameRows)   // Ana & Luis 105, Rafa & Mia 45
        #expect(game.winningAnswer == "Ana & Luis lead by 60, 105 to 45")
    }

    @Test func aTieSaysSoWithTheScore() {
        let game = makeTestGame(rows: [[0, 0], [30, 0], [0, 30]])
        #expect(game.winningAnswer == "All tied up at 30")
    }

    @Test func anEmptyGameSaysNobodyHasScored() {
        let game = makeTestGame()
        #expect(game.winningAnswer == "Nobody has scored yet")
    }

    @Test func pointsToGoCoversBothTeams() {
        let game = makeTestGame(rows: demoGameRows)   // target 200
        #expect(game.pointsToGoAnswer == "Ana & Luis need 95, Rafa & Mia need 155")
    }

    /// Past the target, a team needs nothing — the answer must not say "need 0".
    @Test func aTeamAtTheTargetHasWon() {
        let game = makeTestGame(maxScore: 100, rows: [[0, 0], [100, 0]])
        #expect(game.pointsToGoAnswer == "Ana & Luis have won, Rafa & Mia need 100")
    }

    /// Unnamed teams fall back to the same labels the screen shows.
    @Test func answersUseTheScreensTeamNames() {
        let game = makeTestGame(rows: [[0, 0], [20, 0]], team1: [], team2: [])
        #expect(game.winningAnswer == "Team 1 lead by 20, 20 to 0")
    }

    @Test func contextCarriesBothTeamsAndTheOwner() {
        let game = makeTestGame()
        let context = game.scoreContext(owner: "ana")
        #expect(context.team1 == ["Ana", "Luis"])
        #expect(context.team2 == ["Rafa", "Mia"])
        // The saved player's own spelling, not what was stored.
        #expect(context.owner == "Ana")
        #expect(context.ownTeam == .team1)
    }

    /// A stored owner who is not at this table is not in this game.
    @Test func anOwnerWhoIsNotPlayingIsDropped() {
        let game = makeTestGame()
        let context = game.scoreContext(owner: "Carlos")
        #expect(context.owner == nil)
        #expect(context.ownTeam == .none)
    }
}
