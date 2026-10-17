//
//  Game+Scoreboard.swift
//  iScore
//
//  Derived scoreboard values and display copy for the Duo screens.
//  `scoreTeam` starts with a `[0, 0]` seed row and every round is one-sided
//  (`[points, 0]` or `[0, points]`), so zero rows are never shown as rounds.
//

import Foundation

/// One scored round, derived from a non-zero `scoreTeam` row.
struct Round: Identifiable, Equatable {
    /// Index into `Game.scoreTeam` (used for editing).
    let id: Int
    /// 1-based position among real rounds.
    let number: Int
    let team: Team
    let points: Int
}

extension GameType {

    /// Highest pip count on a tile: 6 or 9.
    var pips: Int {
        switch self {
        case .six: 6
        case .nine: 9
        }
    }
}

extension Game {

    // MARK: - Scores

    func total(for team: Team) -> Int {
        switch team {
        case .team1: totalScore1
        case .team2: totalScore2
        case .none: 0
        }
    }

    /// Share of the target reached, clamped to 0…1.
    func progress(for team: Team) -> Double {
        guard maxScore > 0 else { return 0 }
        return min(max(Double(total(for: team)) / maxScore, 0), 1)
    }

    func pointsToWin(for team: Team) -> Int {
        max(0, Int(maxScore) - total(for: team))
    }

    /// Team with the higher total; `.none` when tied.
    var leader: Team {
        if totalScore1 > totalScore2 { return .team1 }
        if totalScore2 > totalScore1 { return .team2 }
        return .none
    }

    var lead: Int {
        abs(totalScore1 - totalScore2)
    }

    var rounds: [Round] {
        var result: [Round] = []
        for (index, row) in scoreTeam.enumerated() where row.count == 2 {
            if row[0] > 0 {
                result.append(Round(id: index, number: result.count + 1, team: .team1, points: row[0]))
            } else if row[1] > 0 {
                result.append(Round(id: index, number: result.count + 1, team: .team2, points: row[1]))
            }
        }
        return result
    }

    var currentRoundNumber: Int {
        rounds.count + 1
    }

    /// Appends a one-sided round. Ignores non-positive points and `.none`.
    func addRound(_ points: Int, for team: Team) {
        guard points > 0 else { return }
        switch team {
        case .team1: scoreTeam.append([points, 0])
        case .team2: scoreTeam.append([0, points])
        case .none: return
        }
    }

    // MARK: - Names

    func names(for team: Team) -> [String] {
        switch team {
        case .team1: team1
        case .team2: team2
        case .none: []
        }
    }

    /// "Ana & Luis", falling back to "Team 1" / "Team 2" when no names are set.
    func displayName(for team: Team) -> String {
        let joined = names(for: team)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " & ")
        guard joined.isEmpty else { return joined }
        switch team {
        case .team1: return "Team 1"
        case .team2: return "Team 2"
        case .none: return ""
        }
    }

    static func initials(of name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    // MARK: - Copy

    var headline: String {
        if state == .finished, winningTeam != .none {
            return "\(displayName(for: winningTeam)) won!"
        }
        if rounds.isEmpty { return "Let's play!" }
        if leader == .none { return "All tied up" }
        return "\(displayName(for: leader)) lead by \(lead)"
    }

    func projectionSummary(adding points: Int, to team: Team) -> String {
        let current = total(for: team)
        let projected = current + points
        let target = Int(maxScore)
        let outcome = projected >= target ? "Wins the game!" : "\(target - projected) to win"
        return "\(current) → \(projected) · \(outcome)"
    }

    func feedbackDetail(for round: Round) -> String {
        "\(displayName(for: round.team)) +\(round.points) · \(pointsToWin(for: round.team)) to win"
    }
}
