//
//  LockScreenScoringTests.swift
//  iScoreTests
//
//  The "Require unlock to score from Lock Screen" toggle: off by default,
//  shared with the widget, and carried into the activity's state so the
//  buttons become links on the next refresh.
//

import Foundation
import Testing
@testable import iScore

struct LockScreenScoringTests {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "lock-\(UUID().uuidString)")!
    }

    /// Review Focus 7.
    @Test func unlockIsNotRequiredByDefault() {
        #expect(LockScreenScoring.requiresUnlock(defaults()) == false)
    }

    @Test func theToggleIsReadBack() {
        let store = defaults()
        store.set(true, forKey: LockScreenScoring.requireUnlockKey)
        #expect(LockScreenScoring.requiresUnlock(store))
        store.set(false, forKey: LockScreenScoring.requireUnlockKey)
        #expect(LockScreenScoring.requiresUnlock(store) == false)
    }

    @Test func theFlagReachesTheActivityState() {
        let game = Game(gameType: .six, maxScore: 100)
        let on = ScoreboardState.make(from: game, requiresUnlock: true)
        let off = ScoreboardState.make(from: game, requiresUnlock: false)

        #expect(on.requiresUnlock)
        #expect(off.requiresUnlock == false)
        #expect(on != off)
    }
}
