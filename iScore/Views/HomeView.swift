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
    }
}

// MARK: - Toolbar chip

/// Colored icon + number in the Home toolbar (day streak, games finished).
private struct StatChip: View {

    let icon: String
    let value: Int
    let tint: Color
    let label: String

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

    var body: some View {
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
        .buttonStyle(.duoCard)
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
