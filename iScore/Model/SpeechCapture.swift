//
//  SpeechCapture.swift
//  iScore
//
//  On-device speech capture for "say the game into existence". Owns the
//  recognizer and audio engine lifecycle and nothing else: it produces a
//  transcript and knows nothing about games, parsing or SwiftData.
//

import AVFoundation
import Foundation
import Observation
import Speech

/// Whether speech capture can run right now.
enum SpeechAvailability: Equatable {
    case ready
    case needsPermission
    case denied
    case unsupported
}

extension SpeechAvailability {

    /// Pure mapping from the live authorization state. Precedence: a refusal
    /// outranks everything (the user must fix it in Settings), then a missing
    /// answer (we can still ask), then an unusable recognizer.
    static func from(
        speech: SFSpeechRecognizerAuthorizationStatus,
        microphone: AVAudioApplication.recordPermission,
        recognizerAvailable: Bool
    ) -> SpeechAvailability {
        if speech == .denied || speech == .restricted || microphone == .denied {
            return .denied
        }
        if speech == .notDetermined || microphone == .undetermined {
            return .needsPermission
        }
        return recognizerAvailable ? .ready : .unsupported
    }
}

/// Why `SpeechCapture.start()` could not begin listening.
enum SpeechCaptureError: Error, Equatable {
    case unavailable(SpeechAvailability)
}

@MainActor @Observable
final class SpeechCapture {
    private(set) var transcript = ""
    /// Why the last session failed or ended early; nil after a clean start.
    private(set) var lastError: Error?
    private(set) var isListening = false
    private(set) var availability: SpeechAvailability = .needsPermission

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Identifies the current session so late callbacks from a cancelled
    /// task cannot overwrite a newer transcript.
    @ObservationIgnored private var session = 0

    init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
        refreshAvailability()
    }

    /// Asks for speech and microphone permission, then refreshes `availability`.
    func requestAccess() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
            }
        }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        refreshAvailability()
    }

    /// Starts listening. Partial results update `transcript` live.
    func start() throws {
        guard !isListening else { return }
        refreshAvailability()
        do {
            guard availability == .ready else { throw SpeechCaptureError.unavailable(availability) }
            guard let recognizer else { throw SpeechCaptureError.unavailable(.unsupported) }
            try begin(with: recognizer)
        } catch {
            lastError = error
            throw error
        }
    }

    private func begin(with recognizer: SFSpeechRecognizer) throws {
        lastError = nil
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        // A spoken pause becomes a comma, which the parser treats as a break
        // so "nine, two hundred" is not heard as the single number 209.
        request.addsPunctuation = true

        session += 1
        let current = session
        transcript = ""
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || result?.isFinal == true
            let failure = result?.isFinal == true ? nil : error
            Task { @MainActor [weak self] in
                guard let self, self.session == current else { return }
                if let text { self.transcript = text }
                if let failure { self.lastError = failure }
                if finished { self.teardown() }
            }
        }
        self.request = request

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            teardown()
            throw error
        }
        isListening = true
    }

    /// Stops the recognizer and returns the final transcript.
    @discardableResult
    func stop() -> String {
        teardown()
        return transcript
    }

    // MARK: - Private

    private func refreshAvailability() {
        availability = .from(
            speech: SFSpeechRecognizer.authorizationStatus(),
            microphone: AVAudioApplication.shared.recordPermission,
            recognizerAvailable: recognizer?.supportsOnDeviceRecognition == true
        )
    }

    /// Ends the engine, tap, request and task so a second `start()` works.
    private func teardown() {
        session += 1
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
