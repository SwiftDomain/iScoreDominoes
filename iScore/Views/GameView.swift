import SwiftUI
import SwiftData
import TipKit

struct GameView: View {

    @Environment(\.modelContext) private var context
    @Environment(ScoreLinkRouter.self) private var linkRouter
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Game.timestamp, order: .reverse) private var allGames: [Game]

    @Binding var path: NavigationPath
    @Bindable var game: Game
    @State private var team: Team?
    @State private var showGameSummary = false
    @State private var editingRound: Round?
    @State private var showInfoView: Bool = false
    @State private var showUndoConfirmation = false
    @State private var roundCountBeforeSheet = 0
    @State private var feedback: Round?
    @State private var showEndConfirmation = false
    @State private var showCancelConfirmation = false
    /// A heard number with no team: the two team buttons finish the sentence.
    @State private var pendingPoints: Int?
    /// The last spoken answer or refusal, shown on screen as well as spoken.
    @State private var voiceNotice: VoiceNotice?
    /// What the mic has to say for itself, on the row's own full-width line.
    @State private var micLine: String?
    @AppStorage(OwnerIdentity.nameKey) private var ownerName: String = ""
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

    // MARK: - Voice

    /// An answer or refusal on its way to the screen. The id changes with every
    /// delivery, so asking the same question twice gives the second answer its
    /// own full display window instead of the remains of the first's.
    private struct VoiceNotice: Identifiable, Equatable {
        let id = UUID()
        let text: String
    }

    /// "us"/"we" resolves through the owner the Settings screen stored.
    private var voiceContext: ScoreContext {
        let trimmed = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return game.scoreContext(owner: trimmed.isEmpty ? nil : trimmed)
    }

    private var voicePermissions: VoiceScoring.Permissions {
        VoiceScoring.Permissions(canScore: isPlaying, canUndo: game.canUndo)
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

                Menu {
                    Button("End game", systemImage: "flag.checkered") {
                        showEndConfirmation = true
                    }
                    Button("Cancel game", systemImage: "xmark.circle", role: .destructive) {
                        showCancelConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Self.toolbarIconColor(isEnabled: isPlaying))
                }
                .accessibilityLabel("Game options")
                .disabled(!isPlaying)
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(item: $team, onDismiss: applyNewRound) { team in
            AddGameScoreView(game: self.game, team: team)
        }
        .sheet(item: $editingRound, onDismiss: { finishIfWon() }) { round in
            EditScoreView(game: game, round: round)
        }
        .sheet(isPresented: $showGameSummary) {
            GameSummaryView(game: game) { next in
                // Replace the finished game (the top of the path) rather than stacking on it.
                if !path.isEmpty { path.removeLast() }
                path.append(next)
            }
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
        // Same idiom as above: `.alert(_:isPresented:)` with a Bool flag. The
        // newer `item:` overload breaks the Xcode 26 CI build.
        .alert("End this game?", isPresented: $showEndConfirmation) {
            Button("End game") {
                game.endByUser()
                // Never open a summary for a game this alert did not end.
                if game.state == .finished { showGameSummary = true }
            }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("The score stands as it is.")
        }
        .alert("Cancel this game?", isPresented: $showCancelConfirmation) {
            Button("Cancel game", role: .destructive) {
                game.cancelByUser()
                if !path.isEmpty { path.removeLast() }
            }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("It won't count.")
        }
        .task {
            drainLockScreenRounds()
            // "Other…" on the Lock Screen asked for this team's keypad.
            if let deepLinked = linkRouter.takeAddScore(for: game.id) {
                roundCountBeforeSheet = game.rounds.count
                team = deepLinked
            }
            await ScoreActivityController.shared.start(for: game, history: roundHistory)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { drainLockScreenRounds() }
        }
        // Keep the Lock Screen in step with every in-app change: adding,
        // undoing, editing and deleting a round all land in `scoreTeam`.
        .onChange(of: game.scoreTeam) { _, _ in
            Task { await ScoreActivityController.shared.refresh(game, history: roundHistory) }
        }
        .onChange(of: game.state) { _, state in
            Task {
                if state == .playing {
                    await ScoreActivityController.shared.start(for: game, history: roundHistory)
                } else {
                    await ScoreActivityController.shared.end(game)
                }
            }
        }
        .task(id: feedback) {
            guard feedback != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring) { feedback = nil }
        }
        .task(id: voiceNotice?.id) {
            guard voiceNotice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.spring) { voiceNotice = nil }
        }
    }

    // MARK: - Lock Screen activity

    /// Round values this user has scored at this game type, which is what
    /// re-ranks the Lock Screen point grid.
    private var roundHistory: [Int] {
        GameHistory.roundValues(in: allGames, type: game.gameType)
    }

    private func drainLockScreenRounds() {
        ScoreActivityController.shared.drain(into: game, context: context, history: roundHistory)
        finishIfWon()
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

            VStack(spacing: 8) {
                // One line, so a mic that cannot work and an answer the user just
                // asked for never argue with each other. An answer outranks the
                // mic's idle state, and the banner below replaces the buttons,
                // never this line: an answer is never suppressed. A live session
                // outranks both — see `show(_:)`.
                if let line = voiceNotice?.text ?? micLine {
                    Text(line)
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                        // This bar is a fixed inset, not a scroll: an unbounded line at an
                        // accessibility size pushes the score off the screen. Three lines
                        // that shrink hold every reason at ordinary sizes.
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    if let pendingPoints, feedback == nil {
                        askTeamRow(points: pendingPoints)
                    }

                    // The mic sits beside the keypad doors; neither replaces the other.
                    // Three things cannot share one row and all stay legible, so the mic
                    // comes as the button alone and says what it has to say on the
                    // full-width line above, where even the longest reason reads at any
                    // text size.
                    HStack(spacing: 10) {
                        VoiceScoreBar(
                            context: voiceContext,
                            permissions: voicePermissions,
                            answers: game.voiceAnswers,
                            showsText: false,
                            onOutcome: handle,
                            onPrompt: show
                        )
                        addButton(for: .team1)
                            .disabled(!isPlaying)
                        addButton(for: .team2)
                            .disabled(!isPlaying)
                    }
                    // The banner covers the row rather than replacing it. Taking the row
                    // away would unmount the mic after every round, tearing down and
                    // rebuilding the recognizer and the audio engine once per round —
                    // exactly what the capture holder exists to avoid — and laying the
                    // banner out beside the mic instead leaves it too narrow for its own
                    // title and Undo. Covered, it keeps the full width it was drawn for.
                    .accessibilityHidden(feedback != nil)
                    .overlay {
                        if let feedback {
                            RoundFeedbackBanner(round: feedback, game: game) {
                                game.undoLastRound()
                                withAnimation(.spring) { self.feedback = nil }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
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
            // Full size, full style, full behavior; the name is what gives up room.
            Label(game.displayName(for: team), systemImage: "plus")
                .lineLimit(1)
        }
        .buttonStyle(.duo(Theme.palette(for: team)))
        .accessibilityLabel("Add score for \(game.displayName(for: team))")
    }

    /// A heard number with no team. The two team buttons finish the sentence by touch.
    private func askTeamRow(points: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(points) — which team?")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            ForEach([Team.team1, Team.team2], id: \.self) { team in
                Button(game.displayName(for: team)) {
                    record(points, for: team)
                }
                .buttonStyle(.duo(Theme.palette(for: team)))
                .accessibilityLabel("Give \(points) to \(game.displayName(for: team))")
            }
        }
        .disabled(!isPlaying)
    }

    /// The mic's own line. A session that is under way clears the last answer:
    /// a notice lives for six seconds, and within that window the user who taps
    /// the mic again must see `Listening…` and their words, not the last reply.
    private func show(_ report: VoiceBarState.Report) {
        if report.isLive { voiceNotice = nil }
        micLine = report.line
    }

    // MARK: - Voice outcomes

    private func handle(_ outcome: VoiceScoring.Outcome) {
        // Anything but a fresh ask-team closes a question the user has moved on from.
        if case .askTeam = outcome {} else {
            withAnimation(.spring) { pendingPoints = nil }
        }

        switch outcome {
        case let .recorded(points, team):
            record(points, for: team)
        case .undone:
            game.undoLastRound()
            withAnimation(.spring) { feedback = nil }
        case let .askTeam(points):
            withAnimation(.spring) { pendingPoints = points }
        case .confirmEnd:
            showEndConfirmation = true
        case .confirmCancel:
            showCancelConfirmation = true
        // The bar speaks these two itself; showing them here is the other half.
        case let .said(text), let .refused(text):
            withAnimation(.spring) { voiceNotice = VoiceNotice(text: text) }
        }
    }

    // MARK: - Actions

    /// The one way a new round lands, by voice or by the ask-team buttons.
    /// Takes the same post-round path as the Add Score sheet.
    private func record(_ points: Int, for team: Team) {
        pendingPoints = nil
        voiceNotice = nil
        roundCountBeforeSheet = game.rounds.count
        game.addRound(points, for: team)
        applyNewRound()
    }

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

    /// After a new round, by sheet or by voice: finish on a win, otherwise
    /// celebrate it. Shared by both doors so they cannot drift.
    /// (Edit Score only runs `finishIfWon` — editing never shows the banner.)
    private func applyNewRound() {
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
