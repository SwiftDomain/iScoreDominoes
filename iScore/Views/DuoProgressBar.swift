//
//  DuoProgressBar.swift
//  iScore
//
//  Capsule progress bar with a lighter highlight strip and an optional
//  preview segment (where the score will land after adding points).
//

import SwiftUI

struct DuoProgressBar: View {

    let value: Double
    var preview: Double? = nil
    var tint: Color = Theme.teamA
    var previewTint: Color = Theme.teamAWash
    var track: Color = Theme.divider
    var height: CGFloat = 16
    /// VoiceOver name, e.g. "Ana & Luis progress".
    var label: String = "Progress"

    /// Clamps to 0…1; NaN and infinity (e.g. a 0-point target) read as 0.
    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = width * Self.clamped(value)

            ZStack(alignment: .leading) {
                Capsule().fill(track)

                if let preview {
                    Capsule()
                        .fill(previewTint)
                        .frame(width: width * Self.clamped(preview))
                }

                Capsule()
                    .fill(tint)
                    .frame(width: fillWidth)
                    .overlay(alignment: .top) {
                        if fillWidth > 24 {
                            Capsule()
                                .fill(Theme.surface.opacity(0.3))
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                                .padding(.top, height * 0.2)
                        }
                    }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.4), value: value)
        .animation(.spring(duration: 0.3), value: preview)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(Text(Self.clamped(value), format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    VStack(spacing: 20) {
        DuoProgressBar(value: 0)
        DuoProgressBar(value: 0.525)
        DuoProgressBar(value: 1.0)
        DuoProgressBar(value: 0.525, preview: 0.7)
        DuoProgressBar(value: 0.23, tint: Theme.teamB, height: 10)
        DuoProgressBar(value: 0.525, tint: Theme.surface, track: Theme.teamAShadow, height: 12)
            .padding()
            .background(Theme.teamA)
    }
    .padding()
}
