//
//  Game+Voice.swift
//  iScore
//
//  Spoken answers for "who's winning?" and "how many to go?", and the
//  team/owner context the transcript parser needs. Pure copy, no stored state.
//

import Foundation

extension Game {

    // MARK: - Answers

    /// "Ana & Luis lead by 30, 105 to 75" / "All tied up at 60" / "Nobody has scored yet"
    var winningAnswer: String {
        if rounds.isEmpty { return String(localized: "Nobody has scored yet") }
        let high = max(totalScore1, totalScore2)
        let low = min(totalScore1, totalScore2)
        if leader == .none { return String(localized: "All tied up at \(high)") }
        let name = displayName(for: leader)
        return String(localized: "\(name) lead by \(lead), \(high) to \(low)")
    }

    /// "Ana & Luis need 95, Rafa & Mia need 155"; a team at the target has won.
    var pointsToGoAnswer: String {
        String(localized: "\(pointsToGoPhrase(for: .team1)), \(pointsToGoPhrase(for: .team2))")
    }

    private func pointsToGoPhrase(for team: Team) -> String {
        let name = displayName(for: team)
        let needed = pointsToWin(for: team)
        if needed == 0 { return String(localized: "\(name) have won") }
        return String(localized: "\(name) need \(needed)")
    }

    /// Both spoken answers, for `VoiceScoring`, which never sees a `Game`.
    var voiceAnswers: VoiceScoring.Answers {
        VoiceScoring.Answers(winning: winningAnswer, pointsToGo: pointsToGoAnswer)
    }

    // MARK: - Parser context

    /// The teams and the owner, for `ScoreCommand.parse`. An owner who is not
    /// seated at this table comes back nil.
    func scoreContext(owner storedOwnerName: String?) -> ScoreContext {
        ScoreContext(
            team1: team1,
            team2: team2,
            owner: OwnerIdentity.resolve(storedOwnerName, known: team1 + team2)
        )
    }
}
