import AVFoundation
import Foundation
import Speech
import Testing
@testable import iScore

struct SpeechAvailabilityTests {

    /// Review Focus 2 — every permission combination has a defined answer.
    @Test func mapsAuthorizationStates() {
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: true) == .ready)
        #expect(SpeechAvailability.from(speech: .notDetermined, microphone: .granted, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .undetermined, recognizerAvailable: true) == .needsPermission)
        #expect(SpeechAvailability.from(speech: .denied, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .restricted, microphone: .granted, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .denied, recognizerAvailable: true) == .denied)
        #expect(SpeechAvailability.from(speech: .authorized, microphone: .granted, recognizerAvailable: false) == .unsupported)
    }

    @Test func deniedOutranksAMissingRecognizer() {
        #expect(SpeechAvailability.from(speech: .denied, microphone: .denied, recognizerAvailable: false) == .denied)
    }
}
