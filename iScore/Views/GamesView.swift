//
//  GamesView.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/9/23.
//
//  All games, newest first, grouped by month. Search by player name, filter
//  by status, long-press a game to delete it.
//

import SwiftUI
import SwiftData

struct GamesView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Game.timestamp, order: .reverse) private var games: [Game]

    @Binding var path: NavigationPath

    @State private var search = ""
    @State private var filter = GameFilter.all
    @State private var gamePendingDeletion: Game?

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { gamePendingDeletion != nil }, set: { if !$0 { gamePendingDeletion = nil } })
    }

    private var visibleGames: [Game] {
        games.filter { filter.includes($0) && $0.matches(search: search) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All games")
                        .font(DuoFont.title)
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    if !games.isEmpty {
                        Text(GameList.summary(total: games.count, playing: games.filter(GameFilter.playing.includes).count))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                if games.isEmpty {
                    NoGamesView(path: $path)
                } else {
                    SearchWell(prompt: "Search players", text: $search)

                    GameFilterChips(games: games, selection: $filter)

                    if visibleGames.isEmpty {
                        Text("No games match.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    ForEach(GameList.sections(visibleGames)) { section in
                        Text(section.title)
                            .duoLabel()
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(section.games) { game in
                            NavigationLink(destination: GameView(path: $path, game: game)) {
                                GameListCard(game: game)
                            }
                            .buttonStyle(.duoCard)
                            .contextMenu {
                                Button("Delete game", systemImage: "trash", role: .destructive) {
                                    gamePendingDeletion = game
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Background())
        .navigationTitle("All games")
        .toolbarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NewGameView(path: $path)) {
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.textMuted)
                }
                .accessibilityLabel("New game")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        // `isPresented:presenting:` rather than `item:` — the `item:` overloads
        // only exist in the newest SDK and break the Xcode 26 CI build.
        .confirmationDialog(
            "Delete this game?",
            isPresented: isConfirmingDelete,
            titleVisibility: .visible,
            presenting: gamePendingDeletion
        ) { game in
            Button("Delete game", role: .destructive) {
                delete(game)
            }
        } message: { game in
            Text("\(game.displayName(for: .team1)) vs \(game.displayName(for: .team2)) will be removed. Players stay in your list.")
        }
    }

    private func delete(_ game: Game) {
        withAnimation {
            context.deleteGameKeepingPlayers(game)
        }
    }
}

/// All / Playing / Finished / Cancelled with counts.
private struct GameFilterChips: View {

    let games: [Game]
    @Binding var selection: GameFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(GameFilter.allCases) { filter in
                    let isSelected = filter == selection
                    Button {
                        selection = filter
                    } label: {
                        Text("\(filter.title) \(games.filter(filter.includes).count)")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(isSelected ? Theme.teamBShadow : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.duoChoice(isSelected: isSelected, edge: 2))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Empty state: no games at all.
private struct NoGamesView: View {

    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.surface)
                .frame(width: 64, height: 64)
                .duoSolid(fill: Theme.teamB, edge: Theme.teamBShadow, radius: 18)
                .accessibilityHidden(true)

            Text("No games yet")
                .font(DuoFont.title)
                .foregroundStyle(Theme.textPrimary)

            Text("Start one and it shows up here.")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textMuted)

            NavigationLink(destination: NewGameView(path: $path)) {
                Text("Start a game")
            }
            .buttonStyle(.duo(Theme.palette(for: .team1)))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return NavigationStack {
            GamesView(path: .constant(NavigationPath()))
        }
        .modelContainer(previewer.container)
        .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
