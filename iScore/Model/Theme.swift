//
//  Theme.swift
//  iScore
//
//  Semantic color system for iScoreDominoes.
//  "Manga Paper" palette — B&W noir/manga: paper white, ink black,
//  screentone grays. Text on accent fills must use `background` (paper),
//  since the accent itself is ink.
//

import SwiftUI

/// App-wide semantic colors.
/// Use these instead of hardcoded Color literals throughout the app.
enum Theme {

    // MARK: - Backgrounds

    /// Primary app background — Paper
    static let background = Color("background_primary")

    /// Cards, containers, elevated surfaces — White
    static let surface = Color("surface")

    /// Form rows, input wells, secondary containers — Screentone Gray
    static let surfaceSecondary = Color("surfaceSecondary")

    // MARK: - Text

    /// Primary text — Ink
    static let textPrimary = Color("textPrimary")

    /// Subtitles, metadata, labels — Mid Gray
    static let textSecondary = Color("textSecondary")

    // MARK: - Accent

    /// CTAs, win indicators, active states — Ink
    static let accent = Color.accentColor

    /// Accent-colored text and glyphs — Ink (same as accent in this
    /// monochrome palette; kept separate so future palettes can split them)
    static let accentInk = Color("accentInk")

    // MARK: - Semantic

    /// Win badges, positive stats — Charcoal (dark = emphasis)
    static let success = Color("success")

    /// Loss indicators, delete actions — Faded Gray (light = receded)
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
