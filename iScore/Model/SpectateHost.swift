//
//  SpectateHost.swift
//  iScore
//
//  The scorekeeper's rules for a shared game: who is let in, and which game
//  goes out. Two games in one room never cross, because a guest only
//  approaches the host advertising its code and the host checks it again.
//

import Foundation

enum SpectatePolicy {

    static let discoveryKey = "code"

    static func discoveryInfo(for code: JoinCode) -> [String: String] {
        [discoveryKey: code.value]
    }

    /// The guest's side of the check: approach only the host advertising this code.
    static func matches(discoveryInfo: [String: String]?, code: JoinCode) -> Bool {
        discoveryInfo?[discoveryKey] == code.value
    }

    static func invitationContext(for code: JoinCode) -> Data {
        Data(code.value.utf8)
    }

    /// The host's side: an invitation carries the code, exactly, or it is refused.
    static func acceptsInvitation(context: Data?, code: JoinCode) -> Bool {
        guard let context, !context.isEmpty else { return false }
        return context == invitationContext(for: code)
    }

    /// The game going out to the guests: enough to decide what may replace it.
    struct SharedGame: Equatable {
        let id: UUID
        let isPlaying: Bool
        let startedAt: Date

        init(_ game: Game) {
            id = game.id
            isPlaying = game.state == .playing
            startedAt = game.timestamp
        }
    }

    /// The game being shared always goes out, including its final state. Any
    /// other game goes out only while it is being played, and while the shared
    /// game is still playing only if it is newer — the next game of the night.
    /// So neither an old finished game nor an abandoned unfinished one opened
    /// from history ever takes over the broadcast.
    static func shouldPublish(_ game: Game, shared: SharedGame?) -> Bool {
        if game.id == shared?.id { return true }
        guard game.state == .playing else { return false }
        guard let shared, shared.isPlaying else { return true }
        return game.timestamp > shared.startedAt
    }

    static func shared(afterPublishing game: Game, current: SharedGame?) -> SharedGame? {
        shouldPublish(game, shared: current) ? SharedGame(game) : current
    }

    /// A locked scorekeeper drops every guest, so the phone stays awake while
    /// the shared game is played — and not a minute after it ends.
    static func keepsHostAwake(_ shared: SharedGame?) -> Bool {
        shared?.isPlaying == true
    }

    /// One invitation at a time, and only to the host advertising this code.
    static func shouldInvite(discoveryInfo: [String: String]?, code: JoinCode, busy: Bool) -> Bool {
        !busy && matches(discoveryInfo: discoveryInfo, code: code)
    }

    static func watchingLabel(_ count: Int) -> LocalizedStringResource {
        count == 0 ? "Nobody watching yet" : "\(count) watching"
    }
}
