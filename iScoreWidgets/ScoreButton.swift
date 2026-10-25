//
//  ScoreButton.swift
//  iScoreWidgets
//
//  The Duo button vocabulary, rebuilt for a Live Activity: radius 14, a flat
//  team fill and a 4pt darker bottom edge. The app's `.duo` style animates a
//  press, which a widget cannot do, so the shape is reproduced rather than
//  reused. No gradients, shadows, blur or glass.
//

import SwiftUI

struct ScoreButtonFace: View {

    let title: String
    let fill: Color
    let edge: Color
    /// White on a saturated fill; darker on the neutral ones.
    var titleColor: Color = Theme.surface
    var height: CGFloat = 34
    var systemImage: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(edge)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill)
                .padding(.bottom, 4)
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
                .font(DuoFont.label)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .frame(height: height)
    }
}
