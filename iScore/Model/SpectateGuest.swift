//
//  SpectateGuest.swift
//  iScore
//
//  A watching phone's side of a shared game: where the connection stands, and
//  the one thing a guest may ever write — a finished game, saved by a tap.
//  Pure, so every transition is a one-line test; `SpectateGuestLink` feeds it.
//

import Foundation
import SwiftData

enum SpectateGuest {

    enum Phase: Equatable {
        /// Browsing for the host with the code.
        case searching
        case live(SpectateSnapshot)
        /// The host dropped. The last score, if any, is kept but never shown as live.
        case lost(SpectateSnapshot?)
        /// A finished game's final snapshot: the save offer.
        case finished(SpectateSnapshot)
    }

    enum Event: Equatable {
        case received(Data)
        case disconnected
        case reconnecting
    }

    static func reduce(_ phase: Phase, _ event: Event) -> Phase {
        switch event {
        case .received(let data):
            // Anything that is not a believable game leaves the last good state alone.
            guard let snapshot = SpectateSnapshot.decode(data) else { return phase }
            return snapshot.isFinal && snapshot.state == .finished ? .finished(snapshot) : .live(snapshot)
        case .disconnected:
            switch phase {
            case .live(let snapshot): return .lost(snapshot)
            case .searching, .lost, .finished: return phase
            }
        case .reconnecting:
            return phase
        }
    }

    static func status(for phase: Phase) -> LocalizedStringResource {
        switch phase {
        case .searching: "Looking for the game…"
        case .live(let snapshot) where snapshot.isFinal: "Game cancelled"
        case .live: "Live"
        case .lost: "Lost connection. Reconnecting…"
        case .finished: "Final score"
        }
    }
}

/// The guest's single write: a finished game into its own history and stats.
enum SpectateSave {

    /// The same game is already here — through iCloud when the guest shares the
    /// host's account, or from an earlier tap.
    static func isAlreadySaved(_ snapshot: SpectateSnapshot, in games: [Game]) -> Bool {
        games.contains { game in
            game.id == snapshot.gameID
                || (game.gameType == snapshot.gameType
                    && Int(game.maxScore) == snapshot.target
                    && game.scoreTeam == snapshot.scoreTeam
                    && sameNames(game.team1, snapshot.team1)
                    && sameNames(game.team2, snapshot.team2))
        }
    }

    /// Inserts the finished game, reusing players by name. Nil, and nothing
    /// written, unless the snapshot is a finished game's last word and not
    /// already saved.
    @MainActor @discardableResult
    static func save(_ snapshot: SpectateSnapshot, existing: [Player], in context: ModelContext) -> Game? {
        guard snapshot.isFinal, snapshot.state == .finished else { return nil }
        let games = (try? context.fetch(FetchDescriptor<Game>())) ?? []
        guard !isAlreadySaved(snapshot, in: games) else { return nil }

        let game = snapshot.makeDetachedGame()
        game.state = .finished
        game.inProcess = false
        context.insert(game)
        for name in snapshot.team1 + snapshot.team2 {
            let player = existing.first { PlayerName.isSame($0.name, name) } ?? Player(name: name)
            game.players?.append(player)
        }
        return game
    }

    private static func sameNames(_ lhs: [String], _ rhs: [String]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { PlayerName.isSame($0, $1) }
    }
}

/// A guest who shares the host's iCloud account can end up with the saved game
/// twice — its own save and the host's copy syncing in. Both carry the host's
/// id, so the later copies are the extras; the earliest stays.
enum GameDedupe {

    static func extras(in games: [Game]) -> [Game] {
        var seen = Set<UUID>()
        return games.sorted { $0.timestamp < $1.timestamp }.filter { !seen.insert($0.id).inserted }
    }
}
