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

    /// The game being shared always goes out, including its final state. Any
    /// other game goes out only while it is being played — the next game of
    /// the night — so an old game opened from history is never broadcast.
    static func shouldPublish(_ game: Game, sharedGameID: UUID?) -> Bool {
        game.id == sharedGameID || game.state == .playing
    }

    static func sharedGameID(afterPublishing game: Game, current: UUID?) -> UUID? {
        shouldPublish(game, sharedGameID: current) ? game.id : current
    }

    static func watchingLabel(_ count: Int) -> LocalizedStringResource {
        count == 0 ? "Nobody watching yet" : "\(count) watching"
    }
}
