//
//  ScreenAwake.swift
//  iScore
//
//  The one place that decides whether the screen may sleep. Sharing a game,
//  watching one and table mode each need it awake for their own reasons;
//  each holds a reason here instead of flipping the idle timer itself, so
//  leaving one never puts the screen to sleep while another still needs it.
//

import UIKit

enum AwakeReason: Hashable {
    /// The scorekeeper is sharing a game that is being played.
    case sharing
    /// A guest is watching a shared game.
    case watching
    /// The phone lies in the middle of the table.
    case tableMode
}

@MainActor
final class ScreenAwake {

    static let shared = ScreenAwake { UIApplication.shared.isIdleTimerDisabled = $0 }

    private(set) var reasons: Set<AwakeReason> = []
    private let apply: (Bool) -> Void

    var keepsAwake: Bool { !reasons.isEmpty }

    init(apply: @escaping (Bool) -> Void) {
        self.apply = apply
    }

    func set(_ reason: AwakeReason, _ on: Bool) {
        let before = keepsAwake
        if on { reasons.insert(reason) } else { reasons.remove(reason) }
        if keepsAwake != before { apply(keepsAwake) }
    }
}
