//
//  SpokenReply.swift
//  iScore
//
//  Speaks the short answers voice scoring produces ("Ana & Luis lead by 60").
//  Owns the synthesizer and nothing else: it knows nothing about games,
//  parsing or SwiftData.
//

import AVFoundation
import Foundation

/// Whether a spoken answer may be spoken. Pure.
enum VoiceOutput {

    static let speechKey = "voiceSpeechEnabled"

    /// Defaults to true: a feature whose point is talking starts out talking.
    /// `bool(forKey:)` reads a missing key as false, so presence is checked first.
    static func load(from defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: speechKey) != nil else { return true }
        return defaults.bool(forKey: speechKey)
    }

    static func shouldSpeak(isEnabled: Bool) -> Bool {
        isEnabled
    }
}

@MainActor
final class SpokenReply {

    private lazy var synthesizer = AVSpeechSynthesizer()
    private let locale: Locale

    /// The voice language is a parameter, not read from `.current`, so a
    /// user-chosen voice language changes call sites only.
    init(locale: Locale) {
        self.locale = locale
    }

    /// Speaks `text` when `isEnabled`; silently does nothing otherwise.
    ///
    /// Call this only after `SpeechCapture.stop()` has returned, never while a
    /// listening session is open: capture holds the audio session at `.record`
    /// with `.duckOthers` and deactivates it on teardown, so speaking earlier
    /// would fight the microphone for the session and could be cut off by it.
    ///
    /// The Ring/Silent switch is honored by the audio session category, not by
    /// detection: `.ambient` is silenced by the hardware switch. The synthesizer
    /// keeps `usesApplicationAudioSession` at its default `true` so it plays
    /// through the session configured here.
    func say(_ text: String, isEnabled: Bool) {
        guard VoiceOutput.shouldSpeak(isEnabled: isEnabled) else { return }
        // Two quick answers at a table should not queue behind each other.
        synthesizer.stopSpeaking(at: .immediate)

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: locale)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Whether this language has an installed voice. When it does not, the
    /// app still listens and still scores — it just does not speak back, and
    /// Settings says so rather than going quiet mid-game with no explanation.
    nonisolated static func canSpeak(_ locale: Locale,
                                     isInstalled: (String) -> Bool = systemHasVoice) -> Bool {
        voiceLanguage(for: locale, isInstalled: isInstalled) != nil
    }

    /// The voice for `locale`'s BCP-47 identifier, falling back to its bare language code.
    nonisolated static func voice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        voiceLanguage(for: locale, isInstalled: systemHasVoice).flatMap(AVSpeechSynthesisVoice.init(language:))
    }

    /// Which voice language to use, given what is installed. Separate from the
    /// system lookup so the choice is testable without asking the simulator
    /// for its voices, which can block on a fresh CI machine.
    nonisolated static func voiceLanguage(for locale: Locale, isInstalled: (String) -> Bool) -> String? {
        let full = locale.identifier(.bcp47)
        if isInstalled(full) { return full }
        guard let code = locale.language.languageCode?.identifier, isInstalled(code) else { return nil }
        return code
    }

    nonisolated static func systemHasVoice(_ language: String) -> Bool {
        AVSpeechSynthesisVoice(language: language) != nil
    }
}
