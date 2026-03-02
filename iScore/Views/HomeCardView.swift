//
//  HomeCardView.swift
//  iScore
//
//  Card used in the 2x2 grid on the home screen.
//

import SwiftUI

/// A glass-effect card for the home screen grid.
struct HomeCardView: View {

    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Theme.textPrimary)
                .transition(Twirl())

            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Theme.surface.opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.divider, lineWidth: 0.5)
        )
    }
}

#Preview {
    ZStack {
        Background()
        HomeCardView(icon: "plus.circle", title: "New Game", subtitle: "Start playing")
            .padding()
    }
}
