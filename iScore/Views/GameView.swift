import SwiftUI
import SwiftData
import TipKit

struct GameView: View {

    @Binding var path: NavigationPath
    @Bindable var game: Game
    @State private var team: Team?
    @State private var showGameSummary = false
    @State private var editingRound: Round?
    @State private var showInfoView: Bool = false
    @State private var showUndoConfirmation = false
    @State private var roundCountBeforeSheet = 0
    @State private var feedback: Round?
    let editScore = editScoreTip()

    /// The toolbar bar follows the leader; muted and on team 1's value when tied.
    private var progressTeam: Team {
        game.leader == .none ? .team1 : game.leader
    }

    private var progressTint: Color {
        game.leader == .none ? Theme.textMuted : Theme.palette(for: game.leader).fill
    }

    private var isPlaying: Bool {
        game.state == .playing
    }

    /// Toolbar icons carry an explicit color, so they have to dim themselves.
    static func toolbarIconColor(isEnabled: Bool) -> Color {
        isEnabled ? Theme.textMuted : Theme.divider
    }

    var body: some View {
        ScrollView {
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
                .padding(.top, 8)

                roundsSection
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                DuoProgressBar(
                    value: game.progress(for: progressTeam),
                    tint: progressTint,
                    label: game.progressLabel(for: game.leader)
                )
                .frame(width: 180)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showUndoConfirmation = true
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundStyle(Self.toolbarIconColor(isEnabled: game.canUndo))
                }
                .accessibilityLabel("Undo last score")
                .disabled(!game.canUndo)

                Button {
                    showInfoView.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Self.toolbarIconColor(isEnabled: isPlaying))
                }
                .accessibilityLabel("How to play")
                .disabled(!isPlaying)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(item: $team, onDismiss: addScoreDismissed) { team in
            AddGameScoreView(game: self.game, team: team)
        }
        .sheet(item: $editingRound, onDismiss: { finishIfWon() }) { round in
            EditScoreView(game: game, round: round)
        }
        .sheet(isPresented: $showGameSummary) {
            GameSummaryView(game: game)
        }
        .sheet(isPresented: $showInfoView) {
            CollectionView()
        }
        .alert("Undo Last Score", isPresented: $showUndoConfirmation) {
            Button("Undo", role: .destructive) {
                game.undoLastRound()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove the last score entry?")
        }
        .task(id: feedback) {
            guard feedback != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring) { feedback = nil }
        }
    }

    // MARK: - Rounds

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rounds")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(game.rounds.count) played")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.bottom, 6)

            if game.rounds.isEmpty {
                Text("No rounds yet. Add the first score below.")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(game.rounds.reversed()) { round in
                    RoundRow(round: round, teamName: game.displayName(for: round.team))
                        .contentShape(.rect)
                        .onLongPressGesture(minimumDuration: 1) {
                            edit(round)
                        }
                        .accessibilityActions {
                            if game.canEditRounds {
                                Button("Edit score") { edit(round) }
                            }
                        }
                }
            }
        }
        .popoverTip(game.canEditRounds ? editScore : nil)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 2)

            Group {
                if let feedback {
                    RoundFeedbackBanner(round: feedback, game: game)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    HStack(spacing: 10) {
                        addButton(for: .team1)
                        addButton(for: .team2)
                    }
                    .disabled(!isPlaying)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 700)
        }
        .background(Theme.background)
    }

    private func addButton(for team: Team) -> some View {
        Button {
            roundCountBeforeSheet = game.rounds.count
            self.team = team
        } label: {
            Label(game.displayName(for: team), systemImage: "plus")
        }
        .buttonStyle(.duo(Theme.palette(for: team)))
        .accessibilityLabel("Add score for \(game.displayName(for: team))")
    }

    // MARK: - Actions

    private func edit(_ round: Round) {
        guard game.inProcess else { return }
        editingRound = round
    }

    /// Ends the game when a team reached the target. Returns true if it did.
    @discardableResult
    private func finishIfWon() -> Bool {
        guard game.winningTeam != .none, game.state == .playing else { return false }
        game.state = .finished
        game.inProcess = false
        showGameSummary = true
        return true
    }

    /// After Add Score: finish on a win, otherwise celebrate the new round.
    /// (Edit Score only runs `finishIfWon` — editing never shows the banner.)
    private func addScoreDismissed() {
        if finishIfWon() { return }

        if game.rounds.count > roundCountBeforeSheet, let last = game.rounds.last {
            withAnimation(.spring) { feedback = last }
            AccessibilityNotification.Announcement("Nice round! \(game.feedbackDetail(for: last))").post()
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()

        return NavigationStack {
            GameView(path: .constant(NavigationPath()), game: previewer.game)
        }
        .modelContainer(previewer.container)
        .fontDesign(.rounded)
    }
    catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
