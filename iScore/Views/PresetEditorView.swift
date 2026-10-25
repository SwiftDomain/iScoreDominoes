//
//  PresetEditorView.swift
//  iScore
//
//  Create or edit a preset: a name, the four seats, the game and the target —
//  the same pieces New Game uses. Save stays off, with one line saying why,
//  until the preset could start a real game.
//

import SwiftData
import SwiftUI

struct PresetEditorView: View {

    /// nil creates a new preset.
    let preset: GamePreset?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var presets: [GamePreset]

    @State private var name: String
    @State private var gameType: GameType
    @State private var target: Int
    @State private var lineup: PlayerLineup
    @State private var editingSeat: PlayerSeat?

    init(preset: GamePreset?) {
        self.preset = preset
        let defaults = GameDefaults.load()
        _name = State(initialValue: preset?.name ?? "")
        _gameType = State(initialValue: preset?.gameType ?? defaults.type)
        _target = State(initialValue: preset?.target ?? defaults.target)
        var lineup = PlayerLineup()
        for (seat, player) in (preset?.playerNames ?? []).prefix(4).enumerated() {
            lineup.names[seat] = player
        }
        _lineup = State(initialValue: lineup)
    }

    private var setup: PresetSetup {
        PresetSetup(name: PresetName.cleaned(name), gameType: gameType, target: target, playerNames: lineup.names)
    }

    private var blocker: LocalizedStringResource? {
        PresetEditorRules.blocker(name: name, setup: setup, existing: presets.map(\.name), editing: preset?.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: preset == nil ? "New preset" : "Edit preset")

                Text("Preset name")
                    .duoLabel()
                TextField("Friday night", text: $name)
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .duoCard()

                VStack(spacing: 10) {
                    TeamSeatsCard(team: .team1, names: Array(lineup.names[0...1]), onPick: { editingSeat = $0 })
                    TeamSeatsCard(team: .team2, names: Array(lineup.names[2...3]), onPick: { editingSeat = $0 })
                }

                Text("Game")
                    .duoLabel()
                    .padding(.top, 4)
                GameTypePicker(selection: gameType) { type in
                    gameType = type
                    target = type.defaultTarget
                }

                Text("First to")
                    .duoLabel()
                    .padding(.top, 4)
                TargetStepper(target: target, gameType: gameType) { target = $0 }

                if let blocker {
                    Text(blocker)
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button("Save", action: save)
                    .buttonStyle(.duo(Theme.palette(for: .team1)))
                    .disabled(blocker != nil)
            }
            .padding(16)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .sheet(item: $editingSeat) { seat in
            NewPlayerView(
                player: $lineup.names[seat.id],
                seat: seat,
                pickedNames: lineup.pickedNames(excludingSeat: seat.id)
            )
        }
    }

    private func save() {
        guard blocker == nil else { return }
        if let preset {
            preset.name = setup.name
            preset.gameType = setup.gameType
            preset.target = setup.target
            preset.playerNames = setup.playerNames
        } else {
            context.insert(GamePreset(setup))
        }
        dismiss()
    }
}
