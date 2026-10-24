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
    //
    // Spoken answers are in the voice language, which can differ from the app
    // language — so each takes the locale rather than using the process's.

    /// "Ana & Luis lead by 30, 105 to 75" / "All tied up at 60" / "Nobody has scored yet"
    func winningAnswer(in locale: Locale) -> String {
        if rounds.isEmpty { return LocalizedStringResource("Nobody has scored yet").resolved(in: locale) }
        let high = max(totalScore1, totalScore2)
        let low = min(totalScore1, totalScore2)
        if leader == .none { return LocalizedStringResource("All tied up at \(high)").resolved(in: locale) }
        let name = displayName(for: leader)
        return LocalizedStringResource("\(name) lead by \(lead), \(high) to \(low)").resolved(in: locale)
    }

    /// "Ana & Luis need 95, Rafa & Mia need 155"; a team at the target has won.
    func pointsToGoAnswer(in locale: Locale) -> String {
        let first = pointsToGoPhrase(for: .team1, in: locale)
        let second = pointsToGoPhrase(for: .team2, in: locale)
        return LocalizedStringResource("\(first), \(second)").resolved(in: locale)
    }

    private func pointsToGoPhrase(for team: Team, in locale: Locale) -> String {
        let name = displayName(for: team)
        let needed = pointsToWin(for: team)
        if needed == 0 { return LocalizedStringResource("\(name) have won").resolved(in: locale) }
        return LocalizedStringResource("\(name) need \(needed)").resolved(in: locale)
    }

    /// Both spoken answers, for `VoiceScoring`, which never sees a `Game`.
    func voiceAnswers(in locale: Locale) -> VoiceScoring.Answers {
        VoiceScoring.Answers(winning: winningAnswer(in: locale), pointsToGo: pointsToGoAnswer(in: locale))
    }

    // MARK: - Ending a game

    /// Ends a playing game as finished, with the score as it stands. No-op otherwise,
    /// so a second "end the game" can never re-decide a settled game.
    func endByUser() {
        guard state == .playing else { return }
        state = .finished
        inProcess = false
    }

    /// Cancels a playing game. No-op otherwise.
    func cancelByUser() {
        guard state == .playing else { return }
        state = .cancelled
        inProcess = false
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
