import Foundation
import Testing
@testable import iScore

struct GameCommandModelTests {

    static let spoken = "six, 100, Ana Carlos against Luis Papo wrong names"


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

        let merged = GameCommandModel.merged(deterministic: deterministic, model: model, transcript: Self.spoken)
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
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model, transcript: Self.spoken).team1 == ["Ana", "Carlos"])
    }

    @Test func mergeJoinsATwoWordNameTheParserSplit() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Juan", "Carlos", "Ana"]
        deterministic.team2 = ["Luis", "Papo"]
        var model = GameCommand()
        model.team1 = ["Juan Carlos", "Ana"]
        model.team2 = ["Luis", "Papo"]
        let merged = GameCommandModel.merged(
            deterministic: deterministic, model: model,
            transcript: "Juan Carlos y Ana contra Luis y Papo")
        #expect(merged.team1 == ["Juan Carlos", "Ana"])
        #expect(merged.team2 == ["Luis", "Papo"])
    }

    @Test func mergeIgnoresAModelTeamThatContradictsWhatWasHeard() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Ana"]
        var model = GameCommand()
        model.team1 = ["Wrong", "Names"]
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model, transcript: Self.spoken).team1 == ["Ana"])
    }

    @Test func mergeRejectsAnInventedNameAddedToAPartialTeam() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Ana"]
        var model = GameCommand()
        model.team1 = ["Ana", "Invented"]
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model, transcript: "uh Ana").team1 == ["Ana"])
    }

    @Test func mergeCompletesAPartialTeamWithANameThatWasSaid() {
        var deterministic = GameCommand()
        deterministic.team1 = ["Ana"]
        var model = GameCommand()
        model.team1 = ["Ana", "Luís"]
        #expect(GameCommandModel.merged(deterministic: deterministic, model: model, transcript: "uh Ana y LUIS").team1 == ["Ana", "Luís"])
    }

    @Test func mergeFillsAnEmptyCommandFromTheModel() {
        var model = GameCommand()
        model.gameType = .six
        model.target = 100
        model.team1 = ["Ana", "Carlos"]
        model.team2 = ["Luis", "Papo"]
        #expect(GameCommandModel.merged(deterministic: GameCommand(), model: model, transcript: Self.spoken) == model)
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

    /// A complete command with no game type: if the model were wrongly asked, the type it
    /// heard in the transcript would change the result.
    @Test func aCompleteCommandIsReturnedWithoutAsking() async {
        var complete = GameCommand()
        complete.team1 = ["Ana", "Carlos"]
        complete.team2 = ["Luis", "Papo"]
        let result = await GameCommandModel.enhance(
            complete, transcript: "nine two hundred ana carlos against luis papo",
            locale: Locale(identifier: "en_US"), timeout: .seconds(30))
        #expect(result == complete)
    }

    /// With a live model a 1ms timer always wins; without one the guard returns
    /// early. Either way the answer is unchanged.
    ///
    /// Deliberately not timed: this goes through the public entry point, so it
    /// also pays for `SystemLanguageModel.default.availability`, whose cold-start
    /// cost belongs to the host and not to us — it measured 3.6s on a CI runner.
    /// The timeout itself is pinned unconditionally, with no framework involved,
    /// by `aSlowAskerTimesOutToTheDeterministicCommand` below.
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
        #expect(result == deterministic)
    }

    // MARK: - The race, with an injected asker (no device dependence)

    private static var short: GameCommand {
        var command = GameCommand()
        command.gameType = .nine
        command.team1 = ["Ana"]
        return command
    }

    private struct Boom: Error {}

    @Test func aSlowAskerTimesOutToTheDeterministicCommand() async {
        let clock = ContinuousClock()
        var result = GameCommand()
        let elapsed = await clock.measure {
            result = await GameCommandModel.enhance(Self.short, transcript: "nine, Ana and Carlos against Luis and Papo", timeout: .milliseconds(50)) {
                // Ignores cancellation on purpose: the caller must not wait for it.
                // 60s, against a 20s bound below, so the two outcomes are an order of
                // magnitude apart: a working timeout returns in milliseconds (or a few
                // seconds when a loaded runner starves its continuation), a broken one
                // takes the full minute. A 5s-against-2s gap made this a coin flip.
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 60) { c.resume() }
                }
                var late = GameCommand()
                late.team1 = ["Ana", "Carlos"]
                return late
            }
        }
        #expect(result == Self.short)
        #expect(elapsed < .seconds(20))
    }

    @Test func aThrowingAskerReturnsTheDeterministicCommand() async {
        let result = await GameCommandModel.enhance(Self.short, transcript: "nine, Ana and Carlos against Luis and Papo", timeout: .seconds(5)) { throw Boom() }
        #expect(result == Self.short)
    }

    @Test func anAskerReturningNothingReturnsTheDeterministicCommand() async {
        let result = await GameCommandModel.enhance(Self.short, transcript: "nine, Ana and Carlos against Luis and Papo", timeout: .seconds(5)) { nil }
        #expect(result == Self.short)
    }

    @Test func aUsefulAnswerIsMerged() async {
        let result = await GameCommandModel.enhance(Self.short, transcript: "nine, Ana and Carlos against Luis and Papo", timeout: .seconds(5)) {
            var heard = GameCommand()
            heard.target = 150
            heard.team1 = ["Ana", "Carlos"]
            heard.team2 = ["Luis", "Papo"]
            return heard
        }
        #expect(result.gameType == .nine)
        #expect(result.target == 150)
        #expect(result.team1 == ["Ana", "Carlos"])
        #expect(result.team2 == ["Luis", "Papo"])
    }

    // MARK: - Empty team vs the transcript

    private func modelTeams(_ team1: [String], _ team2: [String]) -> GameCommand {
        var model = GameCommand()
        model.team1 = team1
        model.team2 = team2
        return model
    }

    @Test func anEmptyTeamTakesModelNamesThatWereSaid() {
        var heard = GameCommand()
        heard.team1 = ["Ana", "Carlos"]
        let merged = GameCommandModel.merged(
            deterministic: heard, model: modelTeams(["Ana", "Carlos"], ["Luis", "Papo"]),
            transcript: "Ana y CARLOS contra Luís y Papo")
        #expect(merged.team2 == ["Luis", "Papo"])
    }

    @Test func anEmptyTeamRejectsModelNamesNobodySaid() {
        var heard = GameCommand()
        heard.team1 = ["Ana", "Carlos"]
        let merged = GameCommandModel.merged(
            deterministic: heard, model: modelTeams(["Ana", "Carlos"], ["Invented", "Players"]),
            transcript: "uh Ana and Carlos")
        #expect(merged.team2.isEmpty)
        #expect(merged.team1 == ["Ana", "Carlos"])
    }

    @Test func noiseCannotSeatAnyone() {
        let merged = GameCommandModel.merged(
            deterministic: GameCommand(), model: modelTeams(["Ana", "Carlos"], ["Luis", "Papo"]),
            transcript: "uh")
        #expect(merged.team1.isEmpty)
        #expect(merged.team2.isEmpty)
    }
}
