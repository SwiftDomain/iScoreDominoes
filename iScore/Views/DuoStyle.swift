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

/// Pressable white card with a 2pt border and a thicker bottom edge.
struct DuoCardStyle: ButtonStyle {

    var edge: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(DuoCardChrome(edge: edge, border: Theme.divider, pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DuoCardStyle {
    static var duoCard: DuoCardStyle { DuoCardStyle() }
}

/// White card surface. `edge` is the total bottom border thickness (2 = flat).
private struct DuoCardChrome: ViewModifier {

    let edge: CGFloat
    let border: Color
    var pressed = false

    private let shape = RoundedRectangle(cornerRadius: 16)

    /// The 2pt stroke already draws part of the bottom border.
    private var drop: CGFloat { max(edge - 2, 0) }

    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 2))
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

    /// Uppercase tracked label ("ROUND 6 · FIRST TO 200").
    func duoLabel(_ color: Color = Theme.textMuted) -> some View {
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
                    Text("Start playing").font(.caption).foregroundStyle(Theme.textMuted)
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
