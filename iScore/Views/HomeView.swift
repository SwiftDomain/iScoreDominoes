//
//  HomeView.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]
    @Query(sort: \GamePreset.name) private var presets: [GamePreset]

    @Query(
        filter: #Predicate<Game> { $0.inProcess == true },
        sort: \Game.timestamp,
        order: .reverse
    ) private var activeGames: [Game]

    @Query(
        filter: #Predicate<Game> { $0.inProcess == false },
        sort: \Game.timestamp,
        order: .reverse
    ) private var completedGames: [Game]

    @Query(sort: \Game.timestamp, order: .reverse) private var allGames: [Game]

    @Environment(ScoreLinkRouter.self) private var linkRouter
    @Environment(SpectateHostLink.self) private var spectateHost
    @Environment(\.scenePhase) private var scenePhase

    @State private var showHallOfFameView = false
    @State private var showInfoView = false
    @State private var showSettingsView = false
    /// "That's me" from Settings. Read live, so the stats follow every change.
    @AppStorage(OwnerIdentity.nameKey) private var ownerName = ""
    @State private var isSpeaking = false
    @State private var path = NavigationPath()

    private var finishedCount: Int {
        completedGames.filter { $0.state == .finished }.count
    }

    /// Recomputed on every render: when Home appears and whenever "That's me",
    /// the games or the players change.
    private var ownerStats: OwnerStats? {
        let stored = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = OwnerIdentity.resolve(stored.isEmpty ? nil : stored, known: players.map(\.name))
        return OwnerStats.compute(owner: owner, games: allGames)
    }

    private var dayStreak: Int {
        PlayStreak.days(endingOn: .now, playDates: allGames.map(\.timestamp))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Continue card
                    if let activeGame = activeGames.first {
                        NavigationLink(value: activeGame) {
                            ActiveGameBanner(game: activeGame)
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: - Presets
                    let homePresets = PresetList.homeRow(presets)
                    if !homePresets.isEmpty {
                        PresetRow(presets: homePresets, onStart: start)
                    }

                    // MARK: - 2x2 Feature tiles
                    HomeCardGrid(
                        allGamesCount: allGames.count,
                        path: $path,
                        showHallOfFameView: $showHallOfFameView,
                        showInfoView: $showInfoView
                    )

                    // MARK: - Recent Games
                    if !completedGames.isEmpty {
                        RecentGamesSection(games: Array(completedGames.prefix(5)), path: $path)
                    }

                    // MARK: - Quick Stats
                    if !completedGames.isEmpty {
                        QuickStatsSection(stats: ownerStats) { showSettingsView = true }
                    }
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Background())
            .navigationTitle("Dominoes")
            .toolbarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("dominoes")
                        .font(DuoFont.score(26))
                        .foregroundStyle(Theme.teamA)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        StatChip(icon: "flame.fill", value: dayStreak, tint: Theme.streak, label: "Day streak")
                        StatChip(icon: "trophy.fill", value: finishedCount, tint: Theme.gold, label: "Games finished")
                    }
                    .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSpeaking = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(Theme.teamA)
                    }
                    .accessibilityLabel("Say the game")
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettingsView = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.textMuted)
                    }
                    .accessibilityLabel("Settings")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: Game.self) { game in
                GameView(path: $path, game: game)
            }
        }
        .sheet(isPresented: $showHallOfFameView) {
            HallOfFameView()
        }
        .sheet(isPresented: $showInfoView) {
            CollectionView()
        }
        .sheet(isPresented: $showSettingsView) {
            SettingsView()
        }
        .voiceGameSheet(isPresented: $isSpeaking, players: players, presets: presets, onConfirm: start)
        // Rounds may have been scored on the Lock Screen while the app sat
        // on Home; the app is the only writer, so it drains them here too.
        .task {
            drainLockScreenRounds()
            removeDuplicateGames()
        }
        .onOpenURL { url in
            if case let .openAddScore(gameID, team) = ScoreLinkHandler.handle(url, context: context),
               let game = allGames.first(where: { $0.id == gameID }) {
                linkRouter.pendingAddScore = (gameID, team)
                path.append(game)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { drainLockScreenRounds() }
        }
    }

    /// Creates the spoken game and goes straight to its scoreboard.
    fileprivate func start(_ resolved: ResolvedGame) {
        path.append(GameFactory.make(resolved, existing: players, in: context))
    }

    /// One tap: the preset's game, with its players matched to saved ones.
    private func start(_ preset: GamePreset) {
        preset.lastUsed = .now
        start(preset.setup.resolved(known: players.map(\.name)))
    }

    /// A watched game saved on a phone that shares the scorekeeper's iCloud
    /// account arrives twice once iCloud syncs; both copies carry one id.
    private func removeDuplicateGames() {
        for extra in GameDedupe.extras(in: allGames) {
            context.deleteGameKeepingPlayers(extra)
        }
    }

    /// The spec is "while a game is in progress", not "while that game is on
    /// screen", so Home starts the activity too — the app is often left here.
    private func drainLockScreenRounds() {
        guard let game = activeGames.first(where: { $0.state == .playing }) else { return }
        let history = GameHistory.roundValues(in: allGames, type: game.gameType)
        ScoreActivityController.shared.drain(into: game, context: context, history: history)
        Task { await ScoreActivityController.shared.start(for: game, history: history) }
        // Rounds scored on the Lock Screen while sharing reach the watchers too.
        spectateHost.publish(game)
    }
}

// MARK: - Toolbar chip

/// Colored icon + number in the Home toolbar (day streak, games finished).
private struct StatChip: View {

    let icon: String
    let value: Int
    let tint: Color
    let label: LocalizedStringResource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text("\(value)")
                .font(DuoFont.body)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Home Card Grid

/// 2x2 grid of navigation tiles on the home screen.
private struct HomeCardGrid: View {

    let allGamesCount: Int
    @Binding var path: NavigationPath
    @Binding var showHallOfFameView: Bool
    @Binding var showInfoView: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    /// "Watch a game": follow another phone's shared game, read-only.
    @State private var showJoin = false

    var body: some View {
        VStack(spacing: 10) {
            tiles

            Button {
                showJoin = true
            } label: {
                HomeCardView(
                    icon: "eye.fill",
                    title: "Watch a game",
                    subtitle: "Enter a code",
                    tint: Theme.streak
                )
            }
        }
        .buttonStyle(.duoCard)
        .fullScreenCover(isPresented: $showJoin) {
            JoinGameView()
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            NavigationLink(destination: NewGameView(path: $path)) {
                HomeCardView(
                    icon: "plus",
                    title: "New game",
                    subtitle: "Start playing",
                    tint: Theme.teamA
                )
            }

            NavigationLink(destination: GamesView(path: $path)) {
                HomeCardView(
                    icon: "list.bullet.rectangle",
                    title: "All games",
                    subtitle: allGamesCount > 0 ? "\(allGamesCount) games" : "No games yet",
                    tint: Theme.teamB
                )
            }

            Button {
                showHallOfFameView = true
            } label: {
                HomeCardView(
                    icon: "trophy.fill",
                    title: "Hall of fame",
                    subtitle: "Top players",
                    tint: Theme.gold
                )
            }

            Button {
                showInfoView = true
            } label: {
                HomeCardView(
                    icon: "graduationcap.fill",
                    title: "How to play",
                    subtitle: "Learn the rules",
                    tint: Theme.learn
                )
            }
        }
    }
}

// MARK: - Recent Games Section

/// Horizontal scroll of recently completed games.
private struct RecentGamesSection: View {

    let games: [Game]
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent games")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                NavigationLink(destination: GamesView(path: $path)) {
                    Text("View all")
                        .duoLabel(Theme.teamB)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        RecentGameCard(game: game)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

// MARK: - Quick Stats Section

/// Aggregated game stats computed from completed games.
private struct QuickStatsSection: View {

    /// The "That's me" player's record; nil when nobody is set in Settings.
    let stats: OwnerStats?
    let onSetUp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your stats")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)

            if let stats {
                QuickStatsBar(
                    totalGames: stats.played,
                    totalWins: stats.won,
                    winPercentage: stats.winPercentage
                )
            } else {
                // Without a "you", game totals are not your record — say so,
                // and offer the one setting that fixes it.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set \u{201C}That's me\u{201D} in Settings to see your own games, wins and win rate.")
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Settings", systemImage: "gearshape.fill", action: onSetUp)
                        .buttonStyle(.duo(Theme.palette(for: .team1)))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoCard()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    do {
        let previewer = try Previewer()
        return HomeView()
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
