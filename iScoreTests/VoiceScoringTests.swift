import Foundation
import Testing
@testable import iScore

struct VoiceScoringTests {

    private let en = Locale(identifier: "en")
    private let playing = VoiceScoring.Permissions(canScore: true, canUndo: true)
    private let fresh = VoiceScoring.Permissions(canScore: true, canUndo: false)
    private let over = VoiceScoring.Permissions(canScore: false, canUndo: false)
    private let answers = VoiceScoring.Answers(winning: "Ana & Luis lead by 60, 105 to 45",
                                               pointsToGo: "Ana & Luis need 95, Rafa & Mia need 155")

    private func outcome(_ command: ScoreCommand?,
                         _ permissions: VoiceScoring.Permissions,
                         assumedTeam: Team? = nil) -> VoiceScoring.Outcome {
        VoiceScoring.outcome(for: command, permissions: permissions, answers: answers, assumedTeam: assumedTeam, locale: en)
    }

    @Test func aRecordIsRecorded() {
        #expect(outcome(.record(points: 25, team: .team1), playing) == .recorded(points: 25, team: .team1))
    }

    @Test func undoNeedsARoundToTakeBack() {
        #expect(outcome(.undo, playing) == .undone)
        #expect(outcome(.undo, fresh) == .refused(VoiceScoring.nothingToUndo(in: en)))
    }

    /// An undo with nothing left to take back is a refusal, never a phantom round.
    @Test func undoOnAFinishedGameIsRefused() {
        #expect(outcome(.undo, over) == .refused(VoiceScoring.gameIsOver(in: en)))
    }

    @Test func nothingIsScoredOnAGameThatIsOver() {
        #expect(outcome(.record(points: 25, team: .team1), over) == .refused(VoiceScoring.gameIsOver(in: en)))
        #expect(outcome(.askTeam(points: 25), over) == .refused(VoiceScoring.gameIsOver(in: en)))
        #expect(outcome(.endGame, over) == .refused(VoiceScoring.gameIsOver(in: en)))
        #expect(outcome(.cancelGame, over) == .refused(VoiceScoring.gameIsOver(in: en)))
    }

    /// Looking at the score is not scoring.
    @Test func questionsAreAnsweredEvenAfterTheGame() {
        #expect(outcome(.whoIsWinning, over) == .said(answers.winning))
        #expect(outcome(.pointsToGo, over) == .said(answers.pointsToGo))
    }

    /// No team in the sentence, no guess: the question goes back to the user.
    @Test func aBareNumberAsksWhichTeamWhenNoneIsImplied() {
        #expect(outcome(.askTeam(points: 25), playing) == .askTeam(points: 25))
    }

    /// In the Add Score sheet the team is already known, so the number is enough.
    @Test func anAssumedTeamAnswersTheQuestionItself() {
        #expect(outcome(.askTeam(points: 25), playing, assumedTeam: .team2)
                == .recorded(points: 25, team: .team2))
    }

    /// An explicit team in the sentence still wins over the sheet's own team.
    @Test func anExplicitTeamOutranksTheAssumedOne() {
        #expect(outcome(.record(points: 25, team: .team1), playing, assumedTeam: .team2)
                == .recorded(points: 25, team: .team1))
    }

    @Test func endingAndCancellingBothWaitForAConfirmation() {
        #expect(outcome(.endGame, playing) == .confirmEnd)
        #expect(outcome(.cancelGame, playing) == .confirmCancel)
    }

    /// An unparsed transcript is refused with a line the user can read, not swallowed.
    @Test func nothingUnderstoodIsRefusedWithAReason() {
        #expect(outcome(nil, playing) == .refused(VoiceScoring.notUnderstood(in: en)))
        #expect(VoiceScoring.notUnderstood(in: en).isEmpty == false)
        #expect(VoiceScoring.notUnderstood(in: en) != VoiceScoring.nothingToUndo(in: en))
    }

    /// A finished game still has its rounds, so this is the cell that pins the guard order.
    @Test func undoOnAFinishedGameIsRefusedEvenWithRoundsToUndo() {
        let finished = VoiceScoring.Permissions(canScore: false, canUndo: true)
        #expect(outcome(.undo, finished) == .refused(VoiceScoring.gameIsOver(in: en)))
    }

    @Test func questionsAreAnsweredWhilePlayingToo() {
        #expect(outcome(.whoIsWinning, playing) == .said(answers.winning))
        #expect(outcome(.pointsToGo, playing) == .said(answers.pointsToGo))
    }

    /// `Team` has a `.none` case, so an assumed `.none` is no team at all.
    @Test func anAssumedTeamOfNoneIsNoAssumedTeam() {
        #expect(outcome(.askTeam(points: 25), playing, assumedTeam: Team.none) == .askTeam(points: 25))
        #expect(outcome(.askTeam(points: 25), playing, assumedTeam: .team1) == .recorded(points: 25, team: .team1))
    }

    @Test func theThreeRefusalsAreDistinct() {
        let all = [VoiceScoring.notUnderstood(in: en), VoiceScoring.nothingToUndo(in: en), VoiceScoring.gameIsOver(in: en)]
        #expect(Set(all).count == 3)
        #expect(all.allSatisfy { !$0.isEmpty })
    }

    /// A refusal is spoken, so it is in the voice's language too.
    @Test func refusalsAreInTheVoiceLanguage() {
        let outcome = VoiceScoring.outcome(for: nil, permissions: playing, answers: answers,
                                           assumedTeam: nil, locale: Locale(identifier: "es"))
        #expect(outcome == .refused("No se entendió. Di un número y un equipo, o usa el teclado."))
    }
}
