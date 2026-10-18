//
//  VoiceScoreBar.swift
//  iScore
//
//  The one push-to-talk mic for in-game scoring. Tap it, say "forty for us"
//  or "undo", and the host gets an `Outcome` to apply. Push-to-talk only: a
//  tap is the sole thing that starts the recognizer, and it always ends by a
//  second tap, by the recognizer ending itself, or when the screen goes away.
//  A blocked mic stays visible, disabled, and says why; the host's keypad is
//  untouched, so the touch door is never closed.
//

import SwiftUI

/// The bar's own decisions, kept out of the view.
enum VoiceBarState {

    enum Prompt: Equatable {
        case tapToTalk, listening, thinking
        /// The mic cannot be used, or the last session left something to say.
        case blocked(String)
    }

    /// Listening and thinking outrank everything so the bar never nags mid-session;
    /// then a mic that cannot work says why; then the last session's notice.
    static func prompt(isListening: Bool, isThinking: Bool, availability: SpeechAvailability, notice: String?) -> Prompt {
        if isListening { return .listening }
        if isThinking { return .thinking }
        if let why = VoiceSetup.scoringExplanation(availability: availability, error: nil) { return .blocked(why) }
        if let notice { return .blocked(notice) }
        return .tapToTalk
    }

    /// Whether the mic can be tapped at all.
    static func isMicEnabled(availability: SpeechAvailability, isThinking: Bool) -> Bool {
        guard !isThinking else { return false }
        return VoiceSetup.opening(for: availability) != .typeInstead
    }
}

struct VoiceScoreBar: View {

    let context: ScoreContext
    let permissions: VoiceScoring.Permissions
    let answers: VoiceScoring.Answers
    let assumedTeam: Team?
    let locale: Locale
    let onOutcome: (VoiceScoring.Outcome) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(VoiceOutput.speechKey) private var speaksAnswers = true

    /// `@State` initial values are built on every parent body pass; the holder is nearly free
    /// and creates the recognizer, audio engine and synthesizer once, on first use.
    @State private var holder: CaptureHolder
    @State private var isThinking = false
    @State private var notice: String?
    /// Identifies the current screen visit; a wait that outlives it does nothing.
    @State private var visit = 0
    @State private var isOnScreen = false

    init(
        context: ScoreContext,
        permissions: VoiceScoring.Permissions,
        answers: VoiceScoring.Answers,
        assumedTeam: Team? = nil,
        locale: Locale = .current,
        onOutcome: @escaping (VoiceScoring.Outcome) -> Void
    ) {
        self.context = context
        self.permissions = permissions
        self.answers = answers
        self.assumedTeam = assumedTeam
        self.locale = locale
        self.onOutcome = onOutcome
        _holder = State(initialValue: CaptureHolder(locale: locale))
    }

    private var capture: SpeechCapture { holder.capture }

    private var prompt: VoiceBarState.Prompt {
        VoiceBarState.prompt(
            isListening: capture.isListening,
            isThinking: isThinking,
            availability: capture.availability,
            notice: notice
        )
    }

    var body: some View {
        VoiceScoreBarContent(
            prompt: prompt,
            transcript: capture.transcript,
            isListening: capture.isListening,
            isMicEnabled: VoiceBarState.isMicEnabled(availability: capture.availability, isThinking: isThinking),
            onTap: { Task { await toggleListening() } }
        )
        .onChange(of: capture.isListening) { wasListening, isListening in
            if wasListening, !isListening { Task { await listeningEndedByItself() } }
        }
        .onAppear {
            visit += 1
            isOnScreen = true
        }
        .onDisappear { standDown() }
        // A locked or backgrounded phone must not keep listening. Coming back does not restart it.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { standDown() }
        }
    }

    // MARK: - Actions

    /// The one teardown path (screen gone, app backgrounded or locked). Invalidates any wait in
    /// flight, then makes sure the mic is off. Our own stop() flips `isListening`, and that change
    /// must not be mistaken for the recognizer ending. `isOnScreen` returns on the next appear or tap.
    private func standDown() {
        visit += 1
        isOnScreen = false
        isThinking = false
        capture.stop()
    }

    private func toggleListening() async {
        if capture.isListening {
            await finishListening()
        } else {
            await startListening()
        }
    }

    /// Only ever reached from a tap.
    private func startListening() async {
        let current = visit
        notice = nil
        if VoiceSetup.opening(for: capture.availability) == .askPermission {
            await capture.requestAccess()
        }
        // The screen may have gone away while the permission sheet was up.
        guard current == visit else { return }
        // A tap proves the user is here, including after a stand-down with no new appear.
        isOnScreen = true
        guard VoiceSetup.opening(for: capture.availability) == .listen else {
            notice = VoiceSetup.scoringExplanation(availability: capture.availability, error: nil) ?? VoiceSetup.couldntStart
            return
        }
        do {
            try capture.start()
        } catch {
            notice = VoiceSetup.scoringExplanation(availability: capture.availability, error: error) ?? VoiceSetup.couldntStart
        }
    }

    /// The recognizer delivers the last word a moment after the user stops talking.
    private func finishListening() async {
        guard !isThinking else { return }
        let current = visit
        isThinking = true
        try? await Task.sleep(for: .milliseconds(400))
        guard current == visit else {
            isThinking = false
            return
        }
        await conclude(heard: capture.stop())
    }

    /// The recognizer ended the session itself (it failed, or the user fell silent).
    private func listeningEndedByItself() async {
        guard isOnScreen, !isThinking else { return }
        isThinking = true
        await conclude(heard: capture.stop())
    }

    /// Shared wrap-up. Capture is already stopped here, so speaking is safe.
    private func conclude(heard: String) async {
        let reason = VoiceSetup.notice(heard: heard, availability: capture.availability, lastError: capture.lastError)
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        isThinking = false
        notice = reason
        guard !words.isEmpty else { return }

        let command = ScoreCommand.parse(words, locale: locale, context: context)
        let outcome = VoiceScoring.outcome(for: command, permissions: permissions, answers: answers, assumedTeam: assumedTeam)
        onOutcome(outcome)
        switch outcome {
        case .said(let line), .refused(let line):
            holder.reply.say(line, isEnabled: speaksAnswers)
        default:
            break
        }
    }
}

/// The bar's picture: a pure function of what it is told, so the preview can show every state.
private struct VoiceScoreBarContent: View {

    let prompt: VoiceBarState.Prompt
    let transcript: String
    let isListening: Bool
    let isMicEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            micButton

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DuoFont.title)
                    .foregroundStyle(prompt == .listening ? Theme.learnShadow : Theme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(DuoFont.body)
                        .foregroundStyle(isTranscript ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var title: String {
        switch prompt {
        case .tapToTalk: String(localized: "Tap to talk")
        case .listening: String(localized: "Listening…")
        case .thinking: String(localized: "Working it out…")
        case .blocked(let why): why
        }
    }

    private var isTranscript: Bool { prompt == .listening && !transcript.isEmpty }

    private var detail: String? {
        switch prompt {
        case .tapToTalk: String(localized: "“Forty for us”")
        case .listening: transcript.isEmpty ? String(localized: "Say a score, undo, or ask who's winning") : transcript
        case .thinking, .blocked: nil
        }
    }

    private var micButton: some View {
        // Live is neither team's colour, so it can never be mistaken for a team button.
        let palette = isListening
            ? (fill: Theme.learn, edge: Theme.learnShadow)
            : (fill: Theme.palette(for: .team1).fill, edge: Theme.palette(for: .team1).edge)
        return Button(action: onTap) {
            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(DuoCardStyle(edge: 6, radius: 32, border: palette.edge, fill: palette.fill))
        .disabled(!isMicEnabled)
        .opacity(isMicEnabled || prompt == .thinking ? 1 : 0.5)
        .accessibilityLabel(isListening ? String(localized: "Stop listening") : String(localized: "Start listening"))
        .accessibilityHint(String(localized: "Say a score, undo, or ask who's winning"))
        .sensoryFeedback(.impact, trigger: isListening)
    }
}

/// Creates the `SpeechCapture` (recognizer and audio engine) and the synthesizer on first use only.
@MainActor
private final class CaptureHolder {
    private let locale: Locale
    lazy var capture = SpeechCapture(locale: locale)
    lazy var reply = SpokenReply(locale: locale)

    init(locale: Locale) {
        self.locale = locale
    }
}

#Preview {
    VStack(spacing: 12) {
        VoiceScoreBarContent(prompt: .tapToTalk, transcript: "", isListening: false, isMicEnabled: true, onTap: {})
        VoiceScoreBarContent(prompt: .listening, transcript: "forty for Ana and Luis", isListening: true, isMicEnabled: true, onTap: {})
        VoiceScoreBarContent(prompt: .thinking, transcript: "", isListening: false, isMicEnabled: false, onTap: {})
        VoiceScoreBarContent(prompt: .blocked("Microphone access is off. Turn it on in Settings."), transcript: "", isListening: false, isMicEnabled: false, onTap: {})
    }
    .background(Theme.background)
    .fontDesign(.rounded)
}
