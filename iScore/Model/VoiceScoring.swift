//
//  VoiceScoring.swift
//  iScore
//
//  Decides what a parsed spoken command does, given what the game currently
//  allows. Pure: it never sees a Game, so every branch is a one-line test.
//

import Foundation

enum VoiceScoring {

    struct Answers: Equatable {
        let winning: String
        let pointsToGo: String
    }

    /// What the game allows right now.
    struct Permissions: Equatable {
        /// `game.state == .playing`
        let canScore: Bool
        /// `game.canUndo`
        let canUndo: Bool
    }

    enum Outcome: Equatable {
        case recorded(points: Int, team: Team)
        case undone
        /// A number with no team: the host shows both team buttons, points filled in.
        case askTeam(points: Int)
        case confirmEnd
        case confirmCancel
        /// An answer to show and speak. Nothing changes.
        case said(String)
        /// Nothing happened, and this line says why. Shown and spoken.
        case refused(String)
    }

    /// `assumedTeam` is the team the host already knows (the Add Score sheet's team);
    /// nil on `GameView`, where no team is implied. `locale` is the voice language.
    static func outcome(for command: ScoreCommand?,
                        permissions: Permissions,
                        answers: Answers,
                        assumedTeam: Team?,
                        locale: Locale) -> Outcome {
        guard let command else { return .refused(notUnderstood(in: locale)) }

        // Looking back at a score is not scoring, so questions ignore canScore.
        // Every other command is refused first when the game is over.
        let gameOver: Outcome? = permissions.canScore ? nil : .refused(gameIsOver(in: locale))

        switch command {
        case .whoIsWinning:
            return .said(answers.winning)
        case .pointsToGo:
            return .said(answers.pointsToGo)
        case let .record(points, team):
            return gameOver ?? .recorded(points: points, team: team)
        case let .askTeam(points):
            if let gameOver { return gameOver }
            if let assumedTeam, assumedTeam != .none {
                return .recorded(points: points, team: assumedTeam)
            }
            return .askTeam(points: points)
        case .undo:
            return gameOver ?? (permissions.canUndo ? .undone : .refused(nothingToUndo(in: locale)))
        case .endGame:
            return gameOver ?? .confirmEnd
        case .cancelGame:
            return gameOver ?? .confirmCancel
        }
    }

    // Refusals are spoken, so they are in the voice language, not the app's.

    static func notUnderstood(in locale: Locale) -> String {
        LocalizedStringResource("Didn't catch that. Say a number and a team, or use the keypad.").resolved(in: locale)
    }

    static func nothingToUndo(in locale: Locale) -> String {
        LocalizedStringResource("There's nothing to undo yet.").resolved(in: locale)
    }

    static func gameIsOver(in locale: Locale) -> String {
        LocalizedStringResource("This game is over.").resolved(in: locale)
    }
}

/// One listening session yields one result. A session can end two ways — the
/// user taps to finish, or the recognizer ends by itself — and finishing by tap
/// stops the recognizer, which also reads as ending by itself. Whichever path
/// claims the session first scores it; the other finds it already claimed.
struct VoiceSessionGate {

    private var isOpen = false

    /// A session started.
    mutating func begin() {
        isOpen = true
    }

    /// True once per session: the caller concludes it.
    mutating func claim() -> Bool {
        guard isOpen else { return false }
        isOpen = false
        return true
    }
}
