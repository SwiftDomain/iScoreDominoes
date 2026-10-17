//
//  Theme.swift
//  iScore
//
//  Semantic color system for iScoreDominoes.
//  "Duo" palette — Duolingo-inspired: white canvas, rounded gray text,
//  green for team 1 and primary actions, blue for team 2, gold/orange/purple
//  as feature accents. Depth comes from a darker bottom edge (the `…Shadow`
//  colors), never from shadows or gradients. Text on any saturated fill is
//  white (`surface`).
//

import SwiftUI

/// App-wide semantic colors.
/// Use these instead of hardcoded Color literals throughout the app.
enum Theme {

    // MARK: - Backgrounds

    /// Primary app background — White
    static let background = Color("background_primary")

    /// Cards, containers, text on saturated fills — White
    static let surface = Color("surface")

    /// Wells: number display, round circles, neutral chips — Polar
    static let surfaceSecondary = Color("surfaceSecondary")

    // MARK: - Text

    /// Titles and body — Eel gray
    static let textPrimary = Color("textPrimary")

    /// Secondary text — Wolf gray
    static let textSecondary = Color("textSecondary")

    /// Labels, toolbar icons, placeholders — Hare gray
    static let textMuted = Color("textMuted")

    // MARK: - Accent

    /// Primary actions and win indicators — Feather green
    static let accent = Color.accentColor

    /// Green text and glyphs on white or on `teamAWash` — darker green for legibility
    static let accentInk = Color("accentInk")

    // MARK: - Teams

    /// Team 1 fill — Feather green
    static let teamA = Color("teamA")
    /// Pressed edge under team 1 fills
    static let teamAShadow = Color("teamAShadow")
    /// Team 1 tint (chips, feedback banner, preview bar)
    static let teamAWash = Color("teamAWash")

    /// Team 2 fill and links — Macaw blue
    static let teamB = Color("teamB")
    /// Pressed edge under team 2 fills
    static let teamBShadow = Color("teamBShadow")
    /// Team 2 tint
    static let teamBWash = Color("teamBWash")

    // MARK: - Feature accents

    /// Leader crown, trophies, Hall of Fame
    static let gold = Color("gold")
    static let goldShadow = Color("goldShadow")

    /// Day streak, win rate
    static let streak = Color("streak")
    static let streakShadow = Color("streakShadow")

    /// How to Play
    static let learn = Color("learn")
    static let learnShadow = Color("learnShadow")

    // MARK: - Semantic

    /// Win badges, positive stats — green
    static let success = Color("success")

    /// Destructive actions — Cardinal red
    static let danger = Color("danger")
    static let dangerShadow = Color("dangerShadow")

    /// 2pt borders, card bottom edges, empty cells — Swan gray
    static let divider = Color("dividerColor")

    // MARK: - Team palettes

    /// Fill, pressed edge and tint for a team. `.none` gets a neutral gray set.
    static func palette(for team: Team) -> TeamPalette {
        switch team {
        case .team1:
            TeamPalette(fill: teamA, edge: teamAShadow, wash: teamAWash)
        case .team2:
            TeamPalette(fill: teamB, edge: teamBShadow, wash: teamBWash)
        case .none:
            TeamPalette(fill: textMuted, edge: textSecondary, wash: surfaceSecondary)
        }
    }

    // MARK: - Hall of Fame

    /// Gold, silver and bronze for ranks 1–3; nil below the podium.
    static func medal(forRank rank: Int) -> TeamPalette? {
        switch rank {
        case 1: TeamPalette(fill: gold, edge: goldShadow, wash: surfaceSecondary)
        case 2: TeamPalette(fill: textMuted, edge: textSecondary, wash: surfaceSecondary)
        case 3: TeamPalette(fill: streak, edge: streakShadow, wash: surfaceSecondary)
        default: nil
        }
    }

    // MARK: - Player avatars

    /// Fills for a single player's initial circle (players aren't tied to a team).
    static let avatarColors = [teamA, teamB, learn, streak]

    /// Stable per name across launches (`hashValue` is reseeded every run).
    /// FNV-1a, using the high bits: summing characters clusters common names.
    static func avatarColor(for name: String) -> Color {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var hash: UInt32 = 2_166_136_261
        for byte in key.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return avatarColors[Int(hash >> 16) % avatarColors.count]
    }

    /// Every colorset name used above; tests check each one exists so a typo
    /// can't silently render as clear.
    static let colorAssetNames = [
        "AccentColor", "accentInk", "background_primary", "surface", "surfaceSecondary",
        "textPrimary", "textSecondary", "textMuted", "success", "danger", "dangerShadow", "dividerColor",
        "teamA", "teamAShadow", "teamAWash", "teamB", "teamBShadow", "teamBWash",
        "gold", "goldShadow", "streak", "streakShadow", "learn", "learnShadow"
    ]
}

/// The three colors a team's UI is drawn with.
struct TeamPalette {
    let fill: Color
    let edge: Color
    let wash: Color
}

/// Rounded type scale for the Duo style.
enum DuoFont {

    /// Scores and big numbers
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    /// Screen headlines
    static let title: Font = .system(.title2, design: .rounded, weight: .heavy)

    /// Names, body copy, bubbles
    static let body: Font = .system(.body, design: .rounded, weight: .bold)

    /// Uppercase labels and button titles
    static let label: Font = .system(.footnote, design: .rounded, weight: .heavy)
}
