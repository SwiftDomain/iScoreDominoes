//
//  TableModeView.swift
//  iScore
//
//  The phone face-up in the middle of the table: one big half per team,
//  team 2's turned to face the other side, each half one tap from its keypad.
//  Same Duo colors and card shape as everywhere else, just bigger.
//

import SwiftUI

struct TableModeView: View {

    let game: Game
    let onAdd: (Team) -> Void
    let onUndo: () -> Void
    let onExit: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let sideBySide = TableLayout.isSideBySide(proxy.size)
            let layout = sideBySide
                ? AnyLayout(HStackLayout(spacing: 10))
                : AnyLayout(VStackLayout(spacing: 10))
            layout {
                half(for: .team2)
                    .rotationEffect(.degrees(180))
                centerStrip(sideBySide: sideBySide)
                half(for: .team1)
            }
            .padding(10)
        }
        .background(Theme.background)
    }

    private func half(for team: Team) -> some View {
        let palette = Theme.palette(for: team)
        return Button {
            onAdd(team)
        } label: {
            GeometryReader { proxy in
                let total = game.total(for: team)
                VStack(spacing: 4) {
                    Text(game.displayName(for: team))
                        .font(DuoFont.title)
                        .foregroundStyle(palette.edge)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(total)")
                        .font(DuoFont.tableScore(DuoFont.tableScoreSize(forHalf: proxy.size,
                                                                       digits: String(total).count)))
                        .foregroundStyle(palette.fill)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                    Text("\(game.pointsToWin(for: team)) to win")
                        .duoLabel()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .duoCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(game.tableCardLabel(for: team)))
        .accessibilityHint(Text("Add points"))
    }

    private func centerStrip(sideBySide: Bool) -> some View {
        let layout = sideBySide
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(game.statusLabel)
                .duoLabel()
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Spacer(minLength: 8)
            Button("Undo last score", systemImage: "arrow.uturn.backward", action: onUndo)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
                .foregroundStyle(GameView.toolbarIconColor(isEnabled: game.canUndo))
                .disabled(!game.canUndo)
                .frame(minWidth: 44, minHeight: 44)
            Button("Exit table mode", systemImage: "rectangle.split.1x2", action: onExit)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, sideBySide ? 0 : 6)
        .frame(maxWidth: sideBySide ? 120 : .infinity, maxHeight: sideBySide ? .infinity : 52)
    }
}
