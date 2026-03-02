//
//  HomeView.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData

struct HomeView: View {

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

    @State private var showHallOfFameView = false
    @State private var showInfoView = false
    @State private var showSettingsView = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Background()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Active Game Banner
                        if let activeGame = activeGames.first {
                            NavigationLink(value: activeGame) {
                                ActiveGameBanner(game: activeGame)
                            }
                        }

                        // MARK: - 2x2 Card Grid
                        HomeCardGrid(
                            allGamesCount: allGames.count,
                            path: $path,
                            showHallOfFameView: $showHallOfFameView,
                            showInfoView: $showInfoView
                        )

                        // MARK: - Recent Games
                        if !completedGames.isEmpty {
                            RecentGamesSection(games: Array(completedGames.prefix(5)))
                        }

                        // MARK: - Quick Stats
                        if !completedGames.isEmpty {
                            QuickStatsSection(completedGames: completedGames)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 700)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(Text("Dominoes"))
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showSettingsView = true
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
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
    }
}

// MARK: - Home Card Grid

/// 2x2 grid of navigation cards on the home screen.
private struct HomeCardGrid: View {

    let allGamesCount: Int
    @Binding var path: NavigationPath
    @Binding var showHallOfFameView: Bool
    @Binding var showInfoView: Bool

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns) {
            NavigationLink(destination: NewGameView(path: $path)) {
                HomeCardView(
                    icon: "plus.circle",
                    title: "New Game",
                    subtitle: "Start playing"
                )
            }

            NavigationLink(destination: GamesView(path: $path)) {
                HomeCardView(
                    icon: "list.bullet.rectangle",
                    title: "All Games",
                    subtitle: allGamesCount > 0 ? "\(allGamesCount) games" : "No games yet"
                )
            }

            Button {
                showHallOfFameView = true
            } label: {
                HomeCardView(
                    icon: "trophy",
                    title: "Hall of Fame",
                    subtitle: "Top players"
                )
            }

            Button {
                showInfoView = true
            } label: {
                HomeCardView(
                    icon: "play.rectangle",
                    title: "How to Play",
                    subtitle: "Learn the rules"
                )
            }
        }
    }
}

// MARK: - Recent Games Section

/// Horizontal scroll of recently completed games.
private struct RecentGamesSection: View {

    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Games")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(games) { game in
                        RecentGameCard(game: game)
                    }
                }
            }
            .scrollIndicators(.hidden)
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
            Text("Your Stats")
                .font(.headline)
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
    HomeView()
        .modelContainer(for: Game.self, inMemory: true)
}
