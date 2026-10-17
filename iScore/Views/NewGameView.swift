//
//  NewGameView.swift
//  iScore
//
//  Pick four players, the game type and the target, then start. Starts
//  from the defaults saved in Settings.
//

import SwiftUI
import SwiftData

struct NewGameView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Player.name) private var players: [Player]

    @Binding var path: NavigationPath

    @State private var lineup = PlayerLineup()
    @State private var gameType: GameType
    @State private var target: Int
    @State private var editingSeat: PlayerSeat?
    @State private var startedGame: Game?
    @State private var isSpeaking = false

    init(path: Binding<NavigationPath>) {
        _path = path
        let defaults = GameDefaults.load()
        _gameType = State(initialValue: defaults.type)
        _target = State(initialValue: defaults.target)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Who's playing?")
                    .font(DuoFont.title)
                    .foregroundStyle(Theme.textPrimary)

                ZStack {
                    VStack(spacing: 10) {
                        TeamSeatsCard(team: .team1, names: Array(lineup.names[0...1]), onPick: pick)
                        TeamSeatsCard(team: .team2, names: Array(lineup.names[2...3]), onPick: pick)
                    }

                    Text("VS")
                        .font(DuoFont.score(13))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: .circle)
                        .overlay(Circle().strokeBorder(Theme.divider, lineWidth: 2))
                        .accessibilityHidden(true)
                }

                Text("Game")
                    .duoLabel()
                    .padding(.top, 4)

                GameTypePicker(selection: gameType, onSelect: chooseType)

                Text("First to")
                    .duoLabel()
                    .padding(.top, 4)

                TargetStepper(target: target, gameType: gameType) { target = $0 }
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .navigationTitle("New game")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 2)

                VStack(spacing: 8) {
                    if let hint = lineup.hint {
                        Text(hint)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textMuted)
                    }

                    Button("Start game", action: startGame)
                        .buttonStyle(.duo(Theme.palette(for: .team1)))
                        .disabled(!lineup.isComplete)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: 700)
            }
            .background(Theme.background)
        }
        .sheet(item: $editingSeat) { seat in
            NewPlayerView(
                player: $lineup.names[seat.id],
                seat: seat,
                pickedNames: lineup.pickedNames(excludingSeat: seat.id)
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Say the game", systemImage: "mic.fill") {
                    isSpeaking = true
                }
                .tint(Theme.accentInk)
            }
        }
        .sheet(isPresented: $isSpeaking) {
            VoiceGameSheet(
                defaults: GameDefaults.load(),
                known: players.map(\.name),
                owner: OwnerIdentity.resolve(OwnerIdentity.load(), known: players.map(\.name)),
                onConfirm: start
            )
        }
        .navigationDestination(item: $startedGame) { game in
            GameView(path: $path, game: game)
        }
    }

    // MARK: - Actions

    private func pick(_ seat: PlayerSeat) {
        editingSeat = seat
    }

    /// Switching type resets the target to that type's usual value.
    private func chooseType(_ type: GameType) {
        gameType = type
        target = type.defaultTarget
    }

    private func startGame() {
        guard lineup.isComplete else { return }
        start(ResolvedGame(gameType: gameType, target: target, lineup: lineup, newNames: []))
    }

    private func start(_ resolved: ResolvedGame) {
        guard resolved.lineup.isComplete else { return }
        startedGame = GameFactory.make(resolved, existing: players, in: context)
    }
}

#Preview {
    NavigationStack {
        NewGameView(path: .constant(NavigationPath()))
    }
    .modelContainer(for: Game.self, inMemory: true)
    .fontDesign(.rounded)
}
