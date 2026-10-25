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
    /// What a Lock Screen mic tap does once it reaches the bar.
    enum RequestedListen: Equatable {
        /// Nothing was asked.
        case none
        /// Not active yet (still unlocking); try again when the app is.
        case wait
        /// Already listening or working out the last answer; forget it.
        case drop
        case start
    }

    static func requestedListen(_ requested: Bool, isActive: Bool, isListening: Bool, isThinking: Bool) -> RequestedListen {
        guard requested else { return .none }
        guard isActive else { return .wait }
        return isListening || isThinking ? .drop : .start
    }

    static func isMicEnabled(availability: SpeechAvailability, isThinking: Bool) -> Bool {
        guard !isThinking else { return false }
        return VoiceSetup.opening(for: availability) != .typeInstead
    }

    /// The bar's headline for a prompt.
    static func title(for prompt: Prompt) -> String {
        switch prompt {
        case .tapToTalk: String(localized: "Tap to talk")
        case .listening: String(localized: "Listening…")
        case .thinking: String(localized: "Working it out…")
        case .blocked(let why): why
        }
    }

    /// The second line under the headline, when there is one.
    static func detail(for prompt: Prompt, transcript: String) -> String? {
        switch prompt {
        case .tapToTalk: String(localized: "“Forty for us”")
        case .listening: transcript.isEmpty ? String(localized: "Say a score, undo, or ask who's winning") : transcript
        case .thinking, .blocked: nil
        }
    }

    /// Everything the bar has to say, as one line, for a host that shows it on
    /// a full-width row of its own. The mic standing next to two team buttons
    /// has no room for prose, and a reason the user cannot read is no reason at
    /// all. Idle says "Tap to talk" here too: a bare glyph tells a first-time
    /// scorekeeper nothing, and three words cannot cause the wrap that made
    /// the in-row text column untenable.
    static func line(for prompt: Prompt, transcript: String) -> String {
        let headline = title(for: prompt)
        guard let detail = detail(for: prompt, transcript: transcript) else { return headline }
        return "\(headline) \(detail)"
    }

    /// What the bar hands a host that draws its text: the line, plus whether a
    /// session is in flight. A host clears its own stale notice on a live
    /// report, so the last answer can never blank the next `Listening…`.
    struct Report: Equatable {
        let line: String?
        /// Listening or working it out: the user is mid-session, right now.
        let isLive: Bool

        static let idleAway = Report(line: nil, isLive: false)

        init(line: String?, isLive: Bool) {
            self.line = line
            self.isLive = isLive
        }

        init(prompt: Prompt, transcript: String) {
            line = VoiceBarState.line(for: prompt, transcript: transcript)
            isLive = prompt == .listening || prompt == .thinking
        }
    }
}

struct VoiceScoreBar: View {

    let context: ScoreContext
    let permissions: VoiceScoring.Permissions
    let answers: VoiceScoring.Answers
    let assumedTeam: Team?
    let locale: Locale
    /// False where the bar shares a row with other controls: the mic alone,
    /// with the host showing `onPrompt`'s line on a full-width row of its own.
    /// No default: the drawn-in-place layout needs a host wide enough for prose,
    /// and silently handing a new host the layout that failed would be a trap.
    let showsText: Bool
    /// A tap on the Lock Screen mic, carried in by the host: the bar starts
    /// listening once the app is active and sets it back to false.
    @Binding var listenRequested: Bool
    let onOutcome: (VoiceScoring.Outcome) -> Void
    /// What the bar has to say, for the host that shows it. Required for the
    /// same reason: with `showsText: false` and nowhere to send this, the mic
    /// would have no voice at all.
    let onPrompt: (VoiceBarState.Report) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(VoiceOutput.speechKey) private var speaksAnswers = true

    /// `@State` initial values are built on every parent body pass; the holder is nearly free
    /// and creates the recognizer, audio engine and synthesizer once, on first use.
    @State private var holder: CaptureHolder
    @State private var isThinking = false
    /// One result per listening session, however the session ends.
    @State private var session = VoiceSessionGate()
    @State private var notice: String?
    /// Identifies the current screen visit; a wait that outlives it does nothing.
    @State private var visit = 0
    @State private var isOnScreen = false

    init(
        context: ScoreContext,
        permissions: VoiceScoring.Permissions,
        answers: VoiceScoring.Answers,
        assumedTeam: Team? = nil,
        locale: Locale = LanguageSettings.voiceLocale(),
        showsText: Bool,
        listenRequested: Binding<Bool> = .constant(false),
        onOutcome: @escaping (VoiceScoring.Outcome) -> Void,
        onPrompt: @escaping (VoiceBarState.Report) -> Void
    ) {
        self.context = context
        self.permissions = permissions
        self.answers = answers
        self.assumedTeam = assumedTeam
        self.locale = locale
        self.showsText = showsText
        _listenRequested = listenRequested
        self.onOutcome = onOutcome
        self.onPrompt = onPrompt
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

    /// What a compact host puts on its own row.
    private var report: VoiceBarState.Report {
        VoiceBarState.Report(prompt: prompt, transcript: capture.transcript)
    }

    var body: some View {
        VoiceScoreBarContent(
            prompt: prompt,
            transcript: capture.transcript,
            isListening: capture.isListening,
            isMicEnabled: VoiceBarState.isMicEnabled(availability: capture.availability, isThinking: isThinking),
            showsText: showsText,
            onTap: { Task { await toggleListening() } }
        )
        .onChange(of: capture.isListening) { wasListening, isListening in
            if wasListening, !isListening { Task { await listeningEndedByItself() } }
        }
        .onChange(of: report) { _, report in onPrompt(report) }
        .onAppear {
            visit += 1
            isOnScreen = true
            onPrompt(report)
            startRequestedListening()
        }
        .onChange(of: listenRequested) { _, _ in startRequestedListening() }
        .onDisappear {
            standDown()
            onPrompt(.idleAway)
        }
        // A locked or backgrounded phone must not keep listening. Coming back does not restart it;
        // only a Lock Screen mic tap waiting for the app to become active does.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { standDown() } else { startRequestedListening() }
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
        _ = session.claim()
        capture.stop()
    }

    /// The Lock Screen mic tap. It waits for the app to be active, so the
    /// unlock on the way in cannot stand it straight back down.
    private func startRequestedListening() {
        switch VoiceBarState.requestedListen(
            listenRequested,
            isActive: scenePhase == .active,
            isListening: capture.isListening,
            isThinking: isThinking
        ) {
        case .none, .wait:
            return
        case .drop:
            listenRequested = false
        case .start:
            listenRequested = false
            Task { await startListening() }
        }
    }

    private func toggleListening() async {
        if capture.isListening {
            await finishListening()
        } else {
            await startListening()
        }
    }

    /// Only ever reached from a tap: on the mic here, or on the Lock Screen's.
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
            notice = VoiceSetup.scoringExplanation(availability: capture.availability, error: nil) ?? VoiceSetup.scoringCouldntStart
            return
        }
        do {
            try capture.start()
            session.begin()
        } catch {
            notice = VoiceSetup.scoringExplanation(availability: capture.availability, error: error) ?? VoiceSetup.scoringCouldntStart
        }
    }

    /// The recognizer delivers the last word a moment after the user stops talking.
    private func finishListening() async {
        guard !isThinking, session.claim() else { return }
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
        // Our own stop (a finishing tap, a stand-down) has already claimed the
        // session, so it is never mistaken for the recognizer ending.
        guard isOnScreen, !isThinking, session.claim() else { return }
        isThinking = true
        await conclude(heard: capture.stop())
    }

    /// Shared wrap-up. Capture is already stopped here, so speaking is safe.
    private func conclude(heard: String) async {
        let reason = VoiceSetup.scoringNotice(heard: heard, availability: capture.availability, lastError: capture.lastError)
        let words = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        isThinking = false
        notice = reason
        guard !words.isEmpty else { return }

        let command = ScoreCommand.parse(words, locale: locale, context: context)
        let outcome = VoiceScoring.outcome(for: command, permissions: permissions, answers: answers, assumedTeam: assumedTeam, locale: locale)
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
    var showsText = true
    let onTap: () -> Void

    var body: some View {
        if showsText {
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
        } else {
            micButton
        }
    }

    private var title: String { VoiceBarState.title(for: prompt) }


    private var isTranscript: Bool { prompt == .listening && !transcript.isEmpty }

    private var detail: String? { VoiceBarState.detail(for: prompt, transcript: transcript) }

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
        VoiceScoreBarContent(prompt: .listening, transcript: "", isListening: true, isMicEnabled: true, showsText: false, onTap: {})
    }
    .background(Theme.background)
    .fontDesign(.rounded)
}
