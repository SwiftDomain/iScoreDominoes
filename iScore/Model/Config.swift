//
//  Config.swift
//  iScore
//
//  Created by BeastMode on 3/6/24.
//

import SwiftUI

/// App background — flat white.
struct Background: View {

    var body: some View {
        Theme.background
            .ignoresSafeArea()
    }
}

/// Custom transition with rotation and scale.
struct Twirl: Transition {

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.5)
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 20)
            .rotationEffect(.degrees(phase == .willAppear ? 360 : phase == .didDisappear ? -360 : .zero))
            .brightness(phase == .willAppear ? 1.0 : 0)
    }
}
