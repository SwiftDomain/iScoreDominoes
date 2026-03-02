//
//  Theme.swift
//  iScore
//
//  Semantic color system for iScoreDominoes.
//  Accent color (amberGold) should appear on < 10% of any screen.
//

import SwiftUI

/// App-wide semantic colors.
/// Use these instead of hardcoded Color literals throughout the app.
enum Theme {

    // MARK: - Backgrounds

    /// Primary app background — Deep Navy
    static let background = Color("background_primary")

    /// Cards, containers, elevated surfaces — Slate Blue
    static let surface = Color("surface")

    /// Form rows, secondary containers
    static let surfaceSecondary = Color("surfaceSecondary")

    // MARK: - Text

    /// Primary text — White
    static let textPrimary = Color.white

    /// Subtitles, metadata, labels — Cool Gray
    static let textSecondary = Color("textSecondary")

    // MARK: - Accent (< 10% of screen)

    /// CTAs, win indicators, active states — Amber Gold
    static let accent = Color.accentColor

    // MARK: - Semantic

    /// Win badges, positive stats — Emerald
    static let success = Color("success")

    /// Loss indicators, delete actions — Soft Red
    static let danger = Color("danger")

    /// Subtle separation lines
    static let divider = Color("dividerColor")

    // MARK: - Gradients

    /// Standard background gradient (top to bottom)
    static let backgroundGradient = LinearGradient(
        colors: [Color("background_primary"), Color("surface")],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Surface card gradient for elevated containers
    static let surfaceGradient = LinearGradient(
        colors: [Color("surface"), Color("surfaceSecondary")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
