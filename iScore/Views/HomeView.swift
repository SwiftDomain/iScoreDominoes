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
    @State private var isSpeaking = false
    @State private var path = NavigationPath()

    private var finishedCount: Int {
        completedGames.filter { $0.state == .finished }.count
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
                        QuickStatsSection(completedGames: completedGames)
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
        .voiceGameSheet(isPresented: $isSpeaking, players: players, onConfirm: start)
        // Rounds may have been scored on the Lock Screen while the app sat
        // on Home; the app is the only writer, so it drains them here too.
        .task { drainLockScreenRounds() }
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

    let completedGames: [Game]

    private var totalGames: Int {
        completedGames.count
    }

    /// Count games that ended in a finished state (not cancelled).
    private var totalFinished: Int {
        completedGames.filter { $0.state == .finished }.count
    }

    private var winPercentage: Double {
        guard totalGames > 0 else { return 0 }
        return Double(totalFinished) / Double(totalGames) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your stats")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)

            QuickStatsBar(
                totalGames: totalGames,
                totalWins: totalFinished,
                winPercentage: winPercentage
            )
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
