//
//  GameTypePicker.swift
//  iScore
//
//  Double 6 / Double 9 tiles for New Game and Settings. The caller decides
//  what else changes with the type (both reset the target), so selection
//  goes through `onSelect` instead of a binding.
//

import SwiftUI

struct GameTypePicker: View {

    let selection: GameType
    var compact = false
    let onSelect: (GameType) -> Void

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            ForEach(GameType.allCases, id: \.self) { type in
                let isSelected = type == selection
                Button {
                    onSelect(type)
                } label: {
                    HStack(spacing: compact ? 10 : 12) {
                        DominoGlyph(pips: type.pips, height: compact ? 40 : 52)
                        Text(type.title)
                            .font(compact ? .subheadline.weight(.heavy) : DuoFont.body)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(isSelected ? Theme.teamBShadow : Theme.textPrimary)
                    .padding(.horizontal, compact ? 10 : 12)
                    .padding(.vertical, compact ? 8 : 10)
                }
                .buttonStyle(.duoChoice(isSelected: isSelected, edge: compact ? 2 : 4))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    @Previewable @State var type = GameType.nine
    VStack(spacing: 20) {
        GameTypePicker(selection: type) { type = $0 }
        GameTypePicker(selection: type, compact: true) { type = $0 }
    }
    .padding()
}
