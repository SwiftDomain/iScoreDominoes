//
//  GameDrama.swift
//  iScore
//
//  The moments players would call out themselves — capicúa, a big round, a
//  comeback, a zapato, a last-round win, a streak — found from the score and
//  nothing else. Zero most of the time, one at most, ranked so only the best
//  is shown, and never the same kind twice in a game. Copy is in
//  Game+Drama.swift; views only show what comes out of here.
//

import Foundation

enum GameDrama {

    enum Kind: Hashable {
        case capicua, biggestRound, comeback, shutout, comebackWin, lastRoundWin, streak
    }

    enum Highlight: Equatable {
        case capicua(Team)
        case biggestRound(Team, points: Int)
        case comeback(Team, deficit: Int)
        case shutout(winner: Team)
        case comebackWin(Team, deficit: Int)
        case lastRoundWin(Team)
        case streak(name: String, wins: Int)

        var kind: Kind {
            switch self {
            case .capicua: .capicua
            case .biggestRound: .biggestRound
            case .comeback: .comeback
            case .shutout: .shutout
            case .comebackWin: .comebackWin
            case .lastRoundWin: .lastRoundWin
            case .streak: .streak
            }
        }
    }

    /// Earlier rounds that night before a round can be "the biggest", so the
    /// first round of the night never is.
    static let roundsBeforeARecord = 5

    /// How far behind counts as a comeback: a quarter of the target, rounded
    /// up to a multiple of 5 (100 → 25, 150 → 40, 200 → 50).
    static func comebackDeficit(target: Int) -> Int {
        let quarter = (Double(target) / 4 / 5).rounded(.up)
        return max(5, Int(quarter) * 5)
    }

    /// The largest lead `team`'s opponents held after any of the first
    /// `rounds` rounds (all of them when nil).
    static func largestDeficit(of team: Team, in game: Game, rounds: Int? = nil) -> Int {
        var own = 0, other = 0, worst = 0
        for round in game.rounds.prefix(rounds ?? Int.max) {
            if round.team == team { own += round.points } else { other += round.points }
            worst = max(worst, other - own)
        }
        return worst
    }

    /// The largest gap `team` faced in the first `rounds` rounds since it
    /// last led, so an old deficit already recovered is not counted again.
    static func deficitSinceLastLead(of team: Team, in game: Game, rounds: Int) -> Int {
        let lastLead = (0...rounds).last { leader(in: game, rounds: $0) == team } ?? 0
        var own = 0, other = 0, worst = 0
        for (index, round) in game.rounds.prefix(rounds).enumerated() {
            if round.team == team { own += round.points } else { other += round.points }
            if index >= lastLead { worst = max(worst, other - own) }
        }
        return worst
    }

    // MARK: - A new round

    /// The best moment in `round`, just added to `game`, or nil — nil most
    /// of the time. `earlierRoundsTonight` is every round's points played
    /// today before this one, this game's included.
    static func roundHighlight(after round: Round, in game: Game, capicua: Bool,
                               earlierRoundsTonight: [Int], alreadyShown: Set<Kind>) -> Highlight? {
        var candidates: [Highlight] = []
        if capicua { candidates.append(.capicua(round.team)) }

        let before = round.number - 1
        let deficit = deficitSinceLastLead(of: round.team, in: game, rounds: before)
        if deficit >= comebackDeficit(target: Int(game.maxScore)),
           leader(in: game, rounds: before) != round.team,
           leader(in: game, rounds: round.number) == round.team {
            candidates.append(.comeback(round.team, deficit: deficit))
        }

        if earlierRoundsTonight.count >= roundsBeforeARecord,
           earlierRoundsTonight.allSatisfy({ round.points > $0 }) {
            candidates.append(.biggestRound(round.team, points: round.points))
        }

        return candidates.first { !alreadyShown.contains($0.kind) }
    }

    /// The points of every round played on `now`'s day before `round`: other
    /// games started that day, and this game's earlier rounds.
    static func roundsTonight(in games: [Game], before round: Round, of game: Game,
                              now: Date, calendar: Calendar = .current) -> [Int] {
        let others = games
            .filter { $0.id != game.id && calendar.isDate($0.timestamp, inSameDayAs: now) }
            .flatMap { $0.rounds.map(\.points) }
        let earlier = game.rounds.prefix(round.number - 1).map(\.points)
        return others + earlier
    }

    // MARK: - A finished game

    /// Finished games in a row a player must win to be "on a streak".
    static let streakLength = 3

    /// How `game` was won, or nil while it is still being played.
    /// `history` is every game, in any order, `game` included.
    static func finale(of game: Game, history: [Game]) -> Highlight? {
        let winner = game.winningTeam
        guard game.state == .finished, winner != .none else { return nil }
        let loser: Team = winner == .team1 ? .team2 : .team1

        if game.total(for: loser) == 0 { return .shutout(winner: winner) }

        let deficit = largestDeficit(of: winner, in: game)
        if deficit >= comebackDeficit(target: Int(game.maxScore)) {
            return .comebackWin(winner, deficit: deficit)
        }

        let rounds = game.rounds.count
        if rounds > 1, leader(in: game, rounds: rounds - 1) == loser {
            return .lastRoundWin(winner)
        }

        return streak(in: game, history: history)
    }

    /// The longest run of wins among the winning seats, if it is a streak.
    private static func streak(in game: Game, history: [Game]) -> Highlight? {
        let finished = history
            .filter { $0.state == .finished && $0.winningTeam != .none }
            .sorted { $0.timestamp > $1.timestamp }
        var best: (name: String, wins: Int)?
        for name in game.names(for: game.winningTeam) {
            var wins = 0
            for past in finished {
                let seat = team(of: name, in: past)
                guard seat != .none else { continue }
                guard seat == past.winningTeam else { break }
                wins += 1
            }
            if wins >= streakLength, wins > (best?.wins ?? 0) { best = (name, wins) }
        }
        return best.map { .streak(name: $0.name, wins: $0.wins) }
    }

    private static func team(of name: String, in game: Game) -> Team {
        if game.team1.contains(where: { PlayerName.isSame($0, name) }) { return .team1 }
        if game.team2.contains(where: { PlayerName.isSame($0, name) }) { return .team2 }
        return .none
    }

    // MARK: - Helpers

    /// Who led after the first `rounds` rounds; `.none` when tied.
    static func leader(in game: Game, rounds: Int) -> Team {
        var one = 0, two = 0
        for round in game.rounds.prefix(rounds) {
            if round.team == .team1 { one += round.points } else { two += round.points }
        }
        return one > two ? .team1 : two > one ? .team2 : .none
    }
}
