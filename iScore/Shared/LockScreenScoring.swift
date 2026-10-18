//
//  LockScreenScoring.swift
//  iScore
//
//  "Require unlock to score from Lock Screen". Off by default: it is the
//  scorekeeper's own phone on their own table, and the whole point is not
//  having to unlock it. On, the buttons become deep links instead.
//
//  Stored in the App Group defaults so the widget reads the same value.
//

import Foundation

enum LockScreenScoring {

    static let requireUnlockKey = "requireUnlockToScore"

    static func requiresUnlock(_ defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: requireUnlockKey)
    }
}
