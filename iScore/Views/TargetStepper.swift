//
//  TargetStepper.swift
//  iScore
//
//  "First to" target: − / number well / +, in steps of 10 within the game
//  type's range. VoiceOver reads it as one adjustable element.
//

import SwiftUI

struct TargetStepper: View {

    let target: Int
    let gameType: GameType
    var compact = false
    let onChange: (Int) -> Void

    private var range: ClosedRange<Int> { gameType.targetRange }
    private var side: CGFloat { compact ? 44 : 54 }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            stepButton("minus", direction: -1, enabled: target > range.lowerBound)

            Text("\(target)")
                .font(DuoFont.score(compact ? 22 : 30))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText(value: Double(target)))
                .animation(.snappy, value: target)
                .frame(maxWidth: compact ? 76 : .infinity, minHeight: side)
                .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.divider, lineWidth: 2))

            stepButton("plus", direction: 1, enabled: target < range.upperBound)
        }
        .sensoryFeedback(.selection, trigger: target)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("First to")
        .accessibilityValue("\(target) points")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ icon: String, direction: Int, enabled: Bool) -> some View {
        Button {
            step(direction)
        } label: {
            Image(systemName: icon)
                .font(compact ? .body.weight(.heavy) : .title3.weight(.heavy))
                .foregroundStyle(enabled ? Theme.textPrimary : Theme.divider)
                .frame(width: side, height: side - 4)
        }
        .buttonStyle(.duoCard)
        .disabled(!enabled)
    }

    private func step(_ direction: Int) {
        onChange(gameType.steppedTarget(target, by: direction))
    }
}

#Preview {
    @Previewable @State var target = 200
    VStack(spacing: 20) {
        TargetStepper(target: target, gameType: .nine) { target = $0 }
        TargetStepper(target: target, gameType: .nine, compact: true) { target = $0 }
    }
    .padding()
}
