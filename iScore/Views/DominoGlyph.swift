//
//  DominoGlyph.swift
//  iScore
//
//  A standing double domino (6|6 or 9|9) drawn in the current foreground
//  style, for the game-type tiles.
//

import SwiftUI

struct DominoGlyph: View {

    /// 6 or 9 pips per half.
    let pips: Int
    var height: CGFloat = 52

    private var columns: Int { pips == 9 ? 3 : 2 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: height * 0.14) }

    var body: some View {
        VStack(spacing: 0) {
            half
            Rectangle().frame(height: 2)
            half
        }
        .frame(width: height * 0.58, height: height)
        .background(Theme.surface, in: shape)
        .overlay(shape.strokeBorder(lineWidth: 2))
        .accessibilityHidden(true)
    }

    private var half: some View {
        let dot = height * (pips == 9 ? 0.07 : 0.08)
        return Grid(horizontalSpacing: dot * 0.6, verticalSpacing: dot * 0.4) {
            ForEach(0..<3, id: \.self) { _ in
                GridRow {
                    ForEach(0..<columns, id: \.self) { _ in
                        Circle().frame(width: dot, height: dot)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HStack(spacing: 20) {
        DominoGlyph(pips: 6)
        DominoGlyph(pips: 9)
        DominoGlyph(pips: 9, height: 40)
            .foregroundStyle(Theme.teamBShadow)
    }
    .padding()
}
