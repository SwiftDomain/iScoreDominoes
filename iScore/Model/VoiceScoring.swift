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
    /// nil on `GameView`, where no team is implied.
    static func outcome(for command: ScoreCommand?,
                        permissions: Permissions,
                        answers: Answers,
                        assumedTeam: Team?) -> Outcome {
        guard let command else { return .refused(notUnderstood) }

        // Looking back at a score is not scoring, so questions ignore canScore.
        switch command {
        case .whoIsWinning: return .said(answers.winning)
        case .pointsToGo: return .said(answers.pointsToGo)
        default: break
        }

        guard permissions.canScore else { return .refused(gameIsOver) }

        switch command {
        case let .record(points, team):
            return .recorded(points: points, team: team)
        case let .askTeam(points):
            if let assumedTeam, assumedTeam != .none {
                return .recorded(points: points, team: assumedTeam)
            }
            return .askTeam(points: points)
        case .undo:
            return permissions.canUndo ? .undone : .refused(nothingToUndo)
        case .endGame: return .confirmEnd
        case .cancelGame: return .confirmCancel
        case .whoIsWinning, .pointsToGo: return .refused(notUnderstood) // unreachable
        }
    }

    static var notUnderstood: String {
        String(localized: "Didn't catch that. Say a number and a team, or use the keypad.")
    }

    static var nothingToUndo: String {
        String(localized: "There's nothing to undo yet.")
    }

    static var gameIsOver: String {
        String(localized: "This game is over.")
    }
}
