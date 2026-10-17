import Foundation
import Testing
@testable import iScore

struct GameCommandModelTests {

    @Test func skipsTheModelWhenTheSentenceIsComplete() {
        var command = GameCommand()
        command.gameType = .nine
        command.target = 200
        command.team1 = ["Ana", "Carlos"]
        command.team2 = ["Luis", "Papo"]
        #expect(!GameCommandModel.needsModel(command))
    }

    @Test func wantsTheModelWhenNamesAreMissing() {
        var command = GameCommand()
        command.gameType = .nine
        command.team1 = ["Ana"]
        #expect(GameCommandModel.needsModel(command))
        #expect(GameCommandModel.needsModel(GameCommand()))
    }

    @Test func deterministicFieldsAlwaysWin() {
        var deterministic = GameCommand()
        deterministic.gameType = .six
        deterministic.team1 = ["Ana", "Carlos"]

        var model = GameCommand()
        model.gameType = .nine
        model.target = 150
        model.team1 = ["Wrong", "Names"]
        model.team2 = ["Luis", "Papo"]

        let merged = GameCommandModel.merged(deterministic: deterministic, model: model)
        #expect(merged.gameType == .six)
        #expect(merged.team1 == ["Ana", "Carlos"])
        #expect(merged.target == 150)
        #expect(merged.team2 == ["Luis", "Papo"])
    }

    @Test func needsTheModelForAThreeAndOneSplit() {
        var command = GameCommand()
        command.team1 = ["Juan", "Carlos", "Ana"]
        command.team2 = ["Luis"]
        #expect(GameCommandModel.needsModel(command))
    }

    @Test func aMissingTypeOrTargetAloneDoesNotNeedTheModel() {
        var command = GameCommand()
        command.team1 = ["Ana", "Carlos"]
        command.team2 = ["Luis", "Papo"]
        #expect(!GameCommandModel.needsModel(command))
    }

    @Test func mergeCompletesAShortTeamWhenTheModelKeepsWhatWasHeard() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Ana"]
        var model = GameCommand()
        model.team1 = ["Ana", "Carlos"]
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model).team1 == ["Ana", "Carlos"])
    }

    @Test func mergeJoinsATwoWordNameTheParserSplit() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Juan", "Carlos", "Ana"]
        deterministic.team2 = ["Luis", "Papo"]
        var model = GameCommand()
        model.team1 = ["Juan Carlos", "Ana"]
        model.team2 = ["Luis", "Papo"]
        let merged = GameCommandModel.merged(deterministic: deterministic, model: model)
        #expect(merged.team1 == ["Juan Carlos", "Ana"])
        #expect(merged.team2 == ["Luis", "Papo"])
    }

    @Test func mergeIgnoresAModelTeamThatContradictsWhatWasHeard() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Ana"]
        var model = GameCommand()
        model.team1 = ["Wrong", "Names"]
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model).team1 == ["Ana"])
    }

    @Test func mergeFillsAnEmptyCommandFromTheModel() {
        var model = GameCommand()
        model.gameType = .six
        model.target = 100
        model.team1 = ["Ana", "Carlos"]
        model.team2 = ["Luis", "Papo"]
        #expect(GameCommandModel.merged(deterministic: GameCommand(), model: model) == model)
    }

    @Test func modelOutputIsCleanedBeforeItCanBeMerged() {
        let command = GameCommandModel.command(
            gameType: " Nine ", target: 5,
            team1: [" Ana ", "", "ana"], team2: ["Luis"])
        #expect(command.gameType == .nine)
        #expect(command.target == nil)
        #expect(command.team1 == ["Ana"])
        #expect(command.team2 == ["Luis"])
        #expect(GameCommandModel.command(gameType: "unknown", target: 150, team1: [], team2: []).gameType == nil)
        #expect(GameCommandModel.command(gameType: "unknown", target: 150, team1: [], team2: []).target == 150)
    }

    /// With nothing for the model to add (a complete command) the call must return at once and
    /// unchanged on any hardware; this exercises the guard, not the model.
    @Test func aCompleteCommandIsReturnedWithoutAsking() async {
        var complete = GameCommand()
        complete.team1 = ["Ana", "Carlos"]
        complete.team2 = ["Luis", "Papo"]
        let result = await GameCommandModel.enhance(
            complete, transcript: "ana carlos against luis papo",
            locale: Locale(identifier: "en_US"), timeout: .seconds(30))
        #expect(result == complete)
    }

    /// Review Focus 5 — no model, or a model that fails, must not change the answer.
    @Test func fallsBackToTheDeterministicCommand() async {
        var deterministic = GameCommand()
        deterministic.gameType = .nine
        deterministic.team1 = ["Ana"]

        let result = await GameCommandModel.enhance(
            deterministic,
            transcript: "nine, Ana and somebody",
            locale: Locale(identifier: "en_US"),
            timeout: .milliseconds(1)
        )
        #expect(result.gameType == .nine)
        #expect(result.team1.first == "Ana")
    }
}
