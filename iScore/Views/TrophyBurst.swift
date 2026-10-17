//
//  TrophyBurst.swift
//  iScore
//
//  Gold trophy circle with colored sparkles for Game Summary. Pops in on
//  appear unless Reduce Motion is on.
//

import SwiftUI

struct TrophyBurst: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShown = false

    /// Offset, size and color of each sparkle around the trophy.
    private let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, color: Color)] = [
        (-78, -38, 16, Theme.teamB),
        (80, -26, 20, Theme.learn),
        (-62, 34, 12, Theme.streak),
        (66, 40, 14, Theme.teamA)
    ]

    var body: some View {
        ZStack {
            ForEach(sparkles.indices, id: \.self) { index in
                let sparkle = sparkles[index]
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size, weight: .black))
                    .foregroundStyle(sparkle.color)
                    .offset(x: sparkle.x, y: sparkle.y)
                    .scaleEffect(isShown ? 1 : 0.2)
                    .opacity(isShown ? 1 : 0)
            }

            Image(systemName: "trophy.fill")
                .font(.system(size: 46))
                .foregroundStyle(Theme.surface)
                .frame(width: 92, height: 92)
                .background(alignment: .bottom) {
                    ZStack(alignment: .top) {
                        Circle().fill(Theme.goldShadow).offset(y: 5)
                        Circle().fill(Theme.gold)
                    }
                }
                .scaleEffect(isShown ? 1 : 0.3)
                .opacity(isShown ? 1 : 0)
        }
        .frame(height: 112)
        .accessibilityHidden(true)
        .onAppear(perform: show)
    }

    private func show() {
        if reduceMotion {
            isShown = true
        } else {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                isShown = true
            }
        }
    }
}

#Preview {
    TrophyBurst()
        .padding()
}
