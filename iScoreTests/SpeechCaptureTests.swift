import AVFoundation
import Foundation
import Speech
import Testing
@testable import iScore

struct SpeechAvailabilityTests {

    /// Every permission combination has a defined answer.
    @Test func mapsAuthorizationStates() {
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: true) == .ready)
        #expect(SpeechAvailability.from(speech: .notDetermined, microphone: .granted, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .undetermined, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .denied, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .restricted, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .denied, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: false) == .unsupported)
    }

    @Test func refusalOutranksMissingAnswersAndRecognizer() {
        #expect(SpeechAvailability.from(speech: .notDetermined, microphone: .denied, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .denied, microphone: .undetermined, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .notDetermined, microphone: .granted, recognizerAvailable: false) == .needsPermission)
    }

    @Test func deniedOutranksAMissingRecognizer() {
        #expect(SpeechAvailability.from(speech: .denied, microphone: .denied, recognizerAvailable: false) == .denied)
    }

    /// The refusal path depends on live authorization state, which cannot be
    /// faked without a device. Whatever this environment reports, `start()`
    /// must either throw `.unavailable` carrying that state, or be ready.
    @MainActor @Test func startThrowsWhenNotReady() {
        let capture = SpeechCapture(locale: Locale(identifier: "en_US"))
        guard capture.availability != .ready else { return }
        let expected = capture.availability
        #expect(throws: SpeechCaptureError.unavailable(expected)) {
            try capture.start()
        }
        #expect(!capture.isListening)
        #expect(capture.lastError as? SpeechCaptureError == .unavailable(expected))
    }
}
