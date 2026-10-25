//
//  VoiceGameSheet.swift
//  iScore
//
//  "Say the game": tap the mic, say "nine, two hundred, me and Carlos
//  against Luis and Papo", check the filled-in game, start. When speech is
//  unavailable the sheet opens on the same card with a box to type the
//  sentence instead, so it is never a dead end.
//

import SwiftUI

struct VoiceGameSheet: View {

    let defaults: (type: GameType, target: Int)
    let known: [String]
    let owner: String?
    let onConfirm: (ResolvedGame) -> Void

    private enum Phase { case listening, working, review }

    @Environment(\.dismiss) private var dismiss

    /// `@State` initial values are built on every parent body pass; the holder is nearly free
    /// and creates the recognizer and audio engine once, on first use.
    @State private var captureHolder = CaptureHolder()
    @State private var phase = Phase.listening
    @State private var notice: String?
    /// True once the user (or the system) has taken over ending the session.
    @State private var isEnding = false
    @State private var isDismissed = false
    @State private var typed = ""
    @State private var lineup = PlayerLineup()
    @State private var gameType: GameType
    @State private var target: Int
    @State private var editingSeat: PlayerSeat?
    @FocusState private var isTypingFocused: Bool

    init(
        defaults: (type: GameType, target: Int),
        known: [String],
        owner: String?,
        onConfirm: @escaping (ResolvedGame) -> Void
    ) {
        self.defaults = defaults
        self.known = known
        self.owner = owner
        self.onConfirm = onConfirm
        _gameType = State(initialValue: defaults.type)
        _target = State(initialValue: defaults.target)
    }

    private var capture: SpeechCapture { captureHolder.capture }

    private var newNames: [String] {
        VoiceSetup.newNames(in: lineup, known: known, owner: owner)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: phase == .review ? "Check the game" : nil)
                .padding(.horizontal, 16)

            switch phase {
            case .listening, .working: listeningContent
            case .review: reviewContent
            }
        }
        .background(Background())
        .task { await open() }
        .onChange(of: capture.isListening) { wasListening, isListening in
            if wasListening, !isListening { Task { await listeningEndedByItself() } }
        }
        .onDisappear {
            isDismissed = true
            capture.stop()
        }
        .sheet(item: $editingSeat) { seat in
            NewPlayerView(
                player: $lineup.names[seat.id],
                seat: seat,
                pickedNames: lineup.pickedNames(excludingSeat: seat.id)
            )
        }
    }

    // MARK: - Listening

    private var listeningContent: some View {
        VStack(spacing: 20) {
            Spacer()

            if let notice {
                Label(notice, systemImage: "info.circle.fill")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            micButton

            Text(prompt)
                .font(DuoFont.title)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(capture.transcript.isEmpty ? String(localized: "“Nine, two hundred, me and Carlos against Luis and Papo”") : capture.transcript)
                .font(DuoFont.body)
                .foregroundStyle(capture.transcript.isEmpty ? Theme.textMuted : Theme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)

            Spacer()

            Button("Cancel") { cancel() }
                .duoLabel()
                .frame(minHeight: 44)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 700)
    }

    private var prompt: String {
        if phase == .working { return String(localized: "Working it out…") }
        return capture.isListening ? String(localized: "Listening…") : String(localized: "Tap to talk")
    }

    private var micButton: some View {
        let palette = Theme.palette(for: capture.isListening ? .team2 : .team1)
        return Button {
            Task { await toggleListening() }
        } label: {
            Image(systemName: capture.isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .frame(width: 128, height: 128)
        }
        .buttonStyle(DuoCardStyle(edge: 6, radius: 64, border: palette.edge, fill: palette.fill))
        .disabled(phase == .working)
        .accessibilityLabel(capture.isListening ? String(localized: "Stop listening") : String(localized: "Start listening"))
        .accessibilityHint(String(localized: "Say the game type, the target and the two teams"))
        .sensoryFeedback(.impact, trigger: capture.isListening)
    }

    // MARK: - Review

    private var reviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let notice {
                    Label(notice, systemImage: "info.circle.fill")
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if VoiceSetup.opening(for: capture.availability) == .listen {
                    // A misheard name should cost one tap, not a re-open of the sheet.
                    Button("Say it again", systemImage: "mic.fill", action: sayItAgain)
                        .buttonStyle(.duo(Theme.palette(for: .team2)))
                }

                if notice != nil { typedField }

                ZStack {
                    VStack(spacing: 10) {
                        TeamSeatsCard(team: .team1, names: Array(lineup.names[0...1]), onPick: { editingSeat = $0 })
                        TeamSeatsCard(team: .team2, names: Array(lineup.names[2...3]), onPick: { editingSeat = $0 })
                    }

                    Text("VS")
                        .font(DuoFont.score(13))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: .circle)
                        .overlay(Circle().strokeBorder(Theme.divider, lineWidth: 2))
                        .accessibilityHidden(true)
                }

                if !newNames.isEmpty { newChips }

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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { startBar }
    }

    private var typedField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Nine, 200, me and Ana vs Luis and Rafa", text: $typed, axis: .vertical)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isTypingFocused)
                .onSubmit { Task { await fillFromTyped() } }
                .padding(12)
                .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.divider, lineWidth: 2))
                .accessibilityLabel("Game sentence")

            Button("Fill in the game") {
                Task { await fillFromTyped() }
            }
            .buttonStyle(.duo(Theme.palette(for: .team2)))
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var newChips: some View {
        HStack(spacing: 8) {
            ForEach(newNames, id: \.self) { name in
                Text("\(name) · new")
                    .duoLabel(Theme.accentInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.teamAWash, in: .rect(cornerRadius: 8))
                    .accessibilityLabel("\(name), new player")
            }
        }
    }

    private var startBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 2)

            VStack(spacing: 8) {
                if let hint = lineup.hint {
                    Text(hint)
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button("Start game", action: confirm)
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

    // MARK: - Actions

    /// Decides how to open from what speech can do right now.
    private func open() async {
        if VoiceSetup.opening(for: capture.availability) == .askPermission {
            await capture.requestAccess()
        }
        switch VoiceSetup.opening(for: capture.availability) {
        case .listen, .askPermission:
            await startListening()
        case .typeInstead:
            fallBackToTyping(error: nil)
        }
    }

    private func toggleListening() async {
        if capture.isListening {
            await finishListening()
        } else {
            await startListening()
        }
    }

    private func startListening() async {
        do {
            try capture.start()
        } catch {
            fallBackToTyping(error: error)
        }
    }

    /// The recognizer delivers the last word a moment after the user stops talking.
    private func finishListening() async {
        isEnding = true
        phase = .working
        try? await Task.sleep(for: .milliseconds(400))
        guard !isDismissed else { return }
        await conclude(heard: capture.stop())
    }

    /// The recognizer ended the session itself (it failed, or the user fell silent).
    private func listeningEndedByItself() async {
        guard phase == .listening, !isEnding, !isDismissed else { return }
        isEnding = true
        phase = .working
        await conclude(heard: capture.transcript)
    }

    /// Shared wrap-up: reads the reason first, then fills the game from what was heard.
    private func conclude(heard: String) async {
        let reason = VoiceSetup.notice(heard: heard, availability: capture.availability, lastError: capture.lastError)
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { await apply(words) }
        guard !isDismissed else { return }
        notice = reason
        phase = .review
    }

    /// Back to the mic from Review; the filled-in game stays until something new is heard.
    private func sayItAgain() {
        notice = nil
        isEnding = false
        phase = .listening
        Task { await startListening() }
    }

    private func fallBackToTyping(error: Error?) {
        notice = VoiceSetup.explanation(availability: capture.availability, error: error ?? capture.lastError)
            ?? VoiceSetup.couldntStart
        phase = .review
    }

    private func fillFromTyped() async {
        isTypingFocused = false
        await apply(typed)
    }

    private func apply(_ sentence: String) async {
        let resolved = await VoiceSetup.resolve(
            sentence,
            locale: LanguageSettings.voiceLocale(),
            defaults: defaults,
            known: known,
            owner: owner
        )
        lineup = resolved.lineup
        gameType = resolved.gameType
        target = resolved.target
    }

    private func chooseType(_ type: GameType) {
        gameType = type
        target = type.defaultTarget
    }

    private func cancel() {
        isDismissed = true
        capture.stop()
        dismiss()
    }

    private func confirm() {
        guard lineup.isComplete else { return }
        let resolved = ResolvedGame(gameType: gameType, target: target, lineup: lineup, newNames: newNames)
        dismiss()
        onConfirm(resolved)
    }
}

/// Creates the `SpeechCapture` (recognizer and audio engine) on first use only.
@MainActor
private final class CaptureHolder {
    lazy var capture = SpeechCapture(locale: LanguageSettings.voiceLocale())
}

extension View {
    /// Presents the "say the game" sheet. Every mic entry point goes through here so the
    /// owner lookup and known-player list are built one way. `defaults` is read each time the
    /// sheet opens. The sheet only calls `onConfirm` with a complete lineup.
    func voiceGameSheet(
        isPresented: Binding<Bool>,
        players: [Player],
        defaults: @escaping () -> (type: GameType, target: Int) = { GameDefaults.load() },
        onConfirm: @escaping (ResolvedGame) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            let known = players.map(\.name)
            VoiceGameSheet(
                defaults: defaults(),
                known: known,
                owner: OwnerIdentity.resolve(OwnerIdentity.load(), known: known),
                onConfirm: onConfirm
            )
        }
    }
}

#Preview {
    VoiceGameSheet(defaults: (.nine, 100), known: ["Ana", "Luis", "Rafa"], owner: "Ana") { _ in }
        .fontDesign(.rounded)
}
