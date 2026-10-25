//
//  SpectateView.swift
//  iScore
//
//  A guest's live scoreboard, read-only. There is no keypad, no undo, no edit
//  and no mic here — not disabled, absent. The score is drawn from a Game that
//  no context ever sees, so it reads exactly like the scorekeeper's screen and
//  never reaches this phone's store. The one write is "Save to my games", after
//  a finished game.
//

import SwiftData
import SwiftUI

struct SpectateView: View {

    let code: JoinCode
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var players: [Player]
    @Query private var games: [Game]

    @State private var link = SpectateGuestLink()
    @State private var savedGameID: UUID?

    private var phase: SpectateGuest.Phase { link.phase }

    private var snapshot: SpectateSnapshot? {
        switch phase {
        case .searching: nil
        case .live(let snapshot), .finished(let snapshot): snapshot
        case .lost(let snapshot): snapshot
        }
    }

    private var isLost: Bool {
        if case .lost = phase { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let snapshot {
                    scoreboard(snapshot.makeDetachedGame())
                        // A lost connection keeps the last score but never
                        // presents it as live.
                        .opacity(isLost ? 0.45 : 1)
                    if case .finished(let final) = phase {
                        saveButton(final)
                    }
                } else {
                    waiting
                }
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .task {
            ScreenAwake.shared.set(.watching, true)
            link.join(code)
        }
        .onDisappear {
            link.leave()
            ScreenAwake.shared.set(.watching, false)
        }
        // The connection does not survive the background; coming back looks
        // for the host again and gets a fresh score.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { link.join(code) } else { link.leave() }
        }
    }

    private var header: some View {
        HStack {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            Spacer()
            Text(SpectateGuest.status(for: phase))
                .duoLabel(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(statusFill))
        }
    }

    private var statusColor: Color {
        switch phase {
        case .live(let snapshot) where !snapshot.isFinal: Theme.teamAShadow
        case .lost: Theme.danger
        default: Theme.textSecondary
        }
    }

    private var statusFill: Color {
        switch phase {
        case .live(let snapshot) where !snapshot.isFinal: Theme.teamAWash
        default: Theme.surfaceSecondary
        }
    }

    private func scoreboard(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.statusLabel)
                    .duoLabel()
                Text(game.headline)
                    .font(DuoFont.title)
                    .foregroundStyle(Theme.textPrimary)
            }

            HStack(spacing: 12) {
                TeamScoreCard(game: game, team: .team1)
                TeamScoreCard(game: game, team: .team2)
            }

            VStack(spacing: 0) {
                ForEach(game.rounds.reversed()) { round in
                    RoundRow(round: round, teamName: game.displayName(for: round.team))
                }
            }
        }
    }

    private var waiting: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.textMuted)
            Text(code.value)
                .font(DuoFont.score(40))
                .tracking(8)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    @ViewBuilder
    private func saveButton(_ final: SpectateSnapshot) -> some View {
        if savedGameID == final.gameID {
            Label { Text("Saved") } icon: { Image(systemName: "checkmark") }
                .font(DuoFont.body)
                .foregroundStyle(Theme.teamA)
                .frame(maxWidth: .infinity)
        } else if SpectateSave.isAlreadySaved(final, in: games) {
            Text("Already in your games")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
        } else {
            Button("Save to my games") {
                if SpectateSave.save(final, existing: players, in: context) != nil {
                    savedGameID = final.gameID
                }
            }
            .buttonStyle(.duo(Theme.palette(for: .team1)))
        }
    }
}
