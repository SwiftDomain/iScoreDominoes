//
//  DuoStyle.swift
//  iScore
//
//  Pressable button and card styles for the Duo theme. Depth is a darker
//  bottom edge; pressing drops the face onto the edge (no scaling, no shadow).
//

import SwiftUI

// MARK: - Button

/// Solid, full-width button with a darker bottom edge.
struct DuoButtonStyle: ButtonStyle {

    let fill: Color
    let edge: Color
    var foreground: Color = Theme.surface

    func makeBody(configuration: Configuration) -> some View {
        DuoButtonBody(configuration: configuration, fill: fill, edge: edge, foreground: foreground)
    }

    private struct DuoButtonBody: View {
        let configuration: Configuration
        let fill: Color
        let edge: Color
        let foreground: Color

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed && isEnabled
            configuration.label
                .font(DuoFont.label)
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isEnabled ? foreground : Theme.textMuted)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 50)
                .modifier(DuoSolidChrome(
                    fill: isEnabled ? fill : Theme.divider,
                    edge: isEnabled ? edge : .clear,
                    radius: 14,
                    pressed: pressed
                ))
                .animation(.easeOut(duration: 0.08), value: pressed)
        }
    }
}

/// Solid face sitting on a 4pt darker edge; `pressed` drops the face onto it.
private struct DuoSolidChrome: ViewModifier {

    static let edgeHeight: CGFloat = 4

    let fill: Color
    let edge: Color
    let radius: CGFloat
    var pressed = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        content
            .background(fill, in: shape)
            .offset(y: pressed ? Self.edgeHeight : 0)
            .padding(.bottom, Self.edgeHeight)
            .background(alignment: .bottom) {
                shape.fill(edge).padding(.top, Self.edgeHeight)
            }
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == DuoButtonStyle {

    /// Team-colored button: `fill` face, `edge` underneath, white title.
    static func duo(_ palette: TeamPalette) -> DuoButtonStyle {
        DuoButtonStyle(fill: palette.fill, edge: palette.edge)
    }

    static func duo(fill: Color, edge: Color, foreground: Color) -> DuoButtonStyle {
        DuoButtonStyle(fill: fill, edge: edge, foreground: foreground)
    }
}

// MARK: - Card

/// Pressable card with a 2pt border and a thicker bottom edge.
struct DuoCardStyle: ButtonStyle {

    var edge: CGFloat = 4
    var radius: CGFloat = 16
    var border: Color = Theme.divider
    var fill: Color = Theme.surface

    /// How far the face drops onto its edge when pressed.
    var pressDrop: CGFloat { DuoCardChrome.drop(forEdge: edge) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(DuoCardChrome(
                edge: edge,
                border: border,
                fill: fill,
                radius: radius,
                pressed: configuration.isPressed
            ))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DuoCardStyle {
    static var duoCard: DuoCardStyle { DuoCardStyle() }

    /// Keypad key: a white card with the button shape (radius 14, 4pt drop).
    static var duoKey: DuoCardStyle { DuoCardStyle(edge: 6, radius: 14) }

    /// Choice tile or chip: blue outline and tint when selected.
    static func duoChoice(isSelected: Bool, edge: CGFloat = 4) -> DuoCardStyle {
        DuoCardStyle(
            edge: edge,
            border: isSelected ? Theme.teamB : Theme.divider,
            fill: isSelected ? Theme.teamBWash : Theme.surface
        )
    }
}

/// Card surface. `edge` is the total bottom border thickness (2 = flat).
private struct DuoCardChrome: ViewModifier {

    static let borderWidth: CGFloat = 2

    /// The 2pt stroke already draws part of the bottom border.
    static func drop(forEdge edge: CGFloat) -> CGFloat {
        max(edge - borderWidth, 0)
    }

    let edge: CGFloat
    let border: Color
    var fill: Color = Theme.surface
    var radius: CGFloat = 16
    var pressed = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius) }
    private var drop: CGFloat { Self.drop(forEdge: edge) }

    func body(content: Content) -> some View {
        content
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: Self.borderWidth))
            .offset(y: pressed ? drop : 0)
            .padding(.bottom, drop)
            .background(alignment: .bottom) {
                shape.fill(border).padding(.top, drop)
            }
            .contentShape(.rect)
    }
}

extension View {

    /// Non-interactive Duo card.
    func duoCard(edge: CGFloat = 4, border: Color = Theme.divider) -> some View {
        modifier(DuoCardChrome(edge: edge, border: border))
    }

    /// Non-interactive solid surface with a darker bottom edge (the look of a
    /// Duo button, for cards and labels that live inside a larger link).
    func duoSolid(fill: Color, edge: Color, radius: CGFloat = 14) -> some View {
        modifier(DuoSolidChrome(fill: fill, edge: edge, radius: radius))
    }

    /// Uppercase tracked label ("ROUND 6 · FIRST TO 200"). Labels carry
    /// information, so they default to the readable secondary gray.
    func duoLabel(_ color: Color = Theme.textSecondary) -> some View {
        font(DuoFont.label)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

// MARK: - Preview

#Preview("Buttons and cards") {
    ScrollView {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Button("Ana & Luis", systemImage: "plus") {}
                    .buttonStyle(.duo(Theme.palette(for: .team1)))
                Button("Rafa & Mia", systemImage: "plus") {}
                    .buttonStyle(.duo(Theme.palette(for: .team2)))
            }
            Button("Add points") {}
                .buttonStyle(.duo(Theme.palette(for: .team1)))
                .disabled(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Game in progress").duoLabel(Theme.teamAWash)
                Button("Continue") {}
                    .buttonStyle(.duo(fill: Theme.surface, edge: Theme.teamAWash, foreground: Theme.teamA))
            }
            .padding(14)
            .background(Theme.teamA, in: .rect(cornerRadius: 16))

            Button {} label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New game").font(DuoFont.body)
                    Text("Start playing").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .buttonStyle(.duoCard)

            Text("Static card, flat edge")
                .padding()
                .duoCard(edge: 2)
        }
        .padding()
    }
    .background(Theme.background)
}
