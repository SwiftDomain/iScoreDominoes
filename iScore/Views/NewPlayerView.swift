//
//  NewPlayerView.swift
//  iScore
//
//  Created by BeastMode on 2/13/24.
//
//  Player picker for one New Game seat: type a new name or tap a saved
//  player. Players already seated in this game are grayed out.
//

import SwiftUI
import SwiftData

struct NewPlayerView: View {

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Player.name) private var players: [Player]

    @Binding var player: String
    let seat: PlayerSeat
    let pickedNames: [String]

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var palette: TeamPalette { Theme.palette(for: seat.team) }

    private var typedName: String {
        PlayerName.resolve(name, existing: players.map(\.name))
    }

    private func isPicked(_ name: String) -> Bool {
        pickedNames.contains { PlayerName.isSame($0, name) }
    }

    /// Matching players, the ones still free first.
    private var shownPlayers: [Player] {
        let matching = players.filter { PlayerName.matches($0.name, query: name) }
        return matching.filter { !isPicked($0.name) } + matching.filter { isPicked($0.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(label: seat.title)

                Text("Add a player")
                    .font(DuoFont.title)
                    .foregroundStyle(Theme.textPrimary)

                TextField("Type a name", text: $name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.name)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(addTypedName)
                    .onChange(of: name) {
                        name = PlayerName.limited(name)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isNameFocused ? palette.fill : Theme.divider, lineWidth: 2)
                    )

                if !shownPlayers.isEmpty {
                    Text("Your players")
                        .duoLabel()
                        .padding(.top, 6)

                    VStack(spacing: 0) {
                        ForEach(shownPlayers) { saved in
                            let picked = isPicked(saved.name)
                            Button {
                                choose(saved.name)
                            } label: {
                                SavedPlayerRow(name: saved.name, isPicked: picked)
                            }
                            .buttonStyle(.plain)
                            .disabled(picked)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Background())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 2)

                Button("Add player", action: addTypedName)
                    .buttonStyle(.duo(palette))
                    .disabled(typedName.isEmpty || isPicked(typedName))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 500)
            }
            .background(Theme.background)
        }
    }

    // MARK: - Actions

    private func addTypedName() {
        let resolved = typedName
        guard !resolved.isEmpty, !isPicked(resolved) else { return }
        choose(resolved)
    }

    private func choose(_ name: String) {
        player = name
        dismiss()
    }
}

/// A saved player in the picker; grayed with a PICKED chip when already seated.
private struct SavedPlayerRow: View {

    let name: String
    let isPicked: Bool

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatar(name: name, fill: isPicked ? Theme.textMuted : nil)

            Text(name)
                .font(DuoFont.body)
                .foregroundStyle(isPicked ? Theme.textMuted : Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if isPicked {
                Text("Picked")
                    .duoLabel()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 8))
            }
        }
        .padding(.vertical, 9)
        .contentShape(.rect)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.divider).frame(height: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isPicked ? "Already in this game" : "")
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return NewPlayerView(
            player: .constant(""),
            seat: PlayerSeat(team: .team2, position: 1),
            pickedNames: ["Ana", "Luis", "Rafa"]
        )
        .modelContainer(previewer.container)
        .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
