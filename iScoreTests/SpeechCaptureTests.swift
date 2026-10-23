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

    @Test func preflightRejectsEveryNotReadyState() {
        for state in [SpeechAvailability.denied, .needsPermission, .unsupported] {
            #expect(throws: SpeechCaptureError.unavailable(state)) {
                try SpeechCapture.preflight(availability: state, recognizerPresent: true)
            }
        }
    }

    @Test func preflightRejectsAMissingRecognizer() {
        #expect(throws: SpeechCaptureError.unavailable(.unsupported)) {
            try SpeechCapture.preflight(availability: .ready, recognizerPresent: false)
        }
    }

    @Test func preflightPassesWhenReadyWithARecognizer() throws {
        try SpeechCapture.preflight(availability: .ready, recognizerPresent: true)
    }
}
