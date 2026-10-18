import Foundation
import Testing
@testable import iScore

struct VoiceScoringTests {

    private let playing = VoiceScoring.Permissions(canScore: true, canUndo: true)
    private let fresh = VoiceScoring.Permissions(canScore: true, canUndo: false)
    private let over = VoiceScoring.Permissions(canScore: false, canUndo: false)
    private let answers = VoiceScoring.Answers(winning: "Ana & Luis lead by 60, 105 to 45",
                                               pointsToGo: "Ana & Luis need 95, Rafa & Mia need 155")

    private func outcome(_ command: ScoreCommand?,
                         _ permissions: VoiceScoring.Permissions,
                         assumedTeam: Team? = nil) -> VoiceScoring.Outcome {
        VoiceScoring.outcome(for: command, permissions: permissions, answers: answers, assumedTeam: assumedTeam)
    }

    @Test func aRecordIsRecorded() {
        #expect(outcome(.record(points: 25, team: .team1), playing) == .recorded(points: 25, team: .team1))
    }

    @Test func undoNeedsARoundToTakeBack() {
        #expect(outcome(.undo, playing) == .undone)
        #expect(outcome(.undo, fresh) == .refused(VoiceScoring.nothingToUndo))
    }

    /// Review Focus 4: an extra undo is a refusal, never a phantom round.
    @Test func undoOnAFinishedGameIsRefused() {
        #expect(outcome(.undo, over) == .refused(VoiceScoring.gameIsOver))
    }

    @Test func nothingIsScoredOnAGameThatIsOver() {
        #expect(outcome(.record(points: 25, team: .team1), over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.askTeam(points: 25), over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.endGame, over) == .refused(VoiceScoring.gameIsOver))
        #expect(outcome(.cancelGame, over) == .refused(VoiceScoring.gameIsOver))
    }

    /// Looking at the score is not scoring.
    @Test func questionsAreAnsweredEvenAfterTheGame() {
        #expect(outcome(.whoIsWinning, over) == .said(answers.winning))
        #expect(outcome(.pointsToGo, over) == .said(answers.pointsToGo))
    }

    /// Review Focus 1: no team, no guess.
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

    /// Review Focus 1: an unparsed transcript is refused with a line, not swallowed.
    @Test func nothingUnderstoodIsRefusedWithAReason() {
        #expect(outcome(nil, playing) == .refused(VoiceScoring.notUnderstood))
        #expect(VoiceScoring.notUnderstood.isEmpty == false)
        #expect(VoiceScoring.notUnderstood != VoiceScoring.nothingToUndo)
    }
}
