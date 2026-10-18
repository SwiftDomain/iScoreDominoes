import Foundation
import Testing
@testable import iScore

struct VoiceScoreBarTests {

    @Test func thePromptFollowsTheState() {
        #expect(VoiceBarState.prompt(isListening: false, isThinking: false, availability: .ready, notice: nil) == .tapToTalk)
        #expect(VoiceBarState.prompt(isListening: true, isThinking: false, availability: .ready, notice: nil) == .listening)
        #expect(VoiceBarState.prompt(isListening: false, isThinking: true, availability: .ready, notice: nil) == .thinking)
    }

    /// Review Focus 5: a blocked mic says why, and says it in the prompt, not nowhere.
    @Test func aBlockedMicExplainsItself() {
        let denied = VoiceBarState.prompt(isListening: false, isThinking: false, availability: .denied, notice: nil)
        #expect(denied == .blocked(VoiceSetup.explanation(availability: .denied, error: nil)!))
        let unsupported = VoiceBarState.prompt(isListening: false, isThinking: false, availability: .unsupported, notice: nil)
        #expect(unsupported != denied)
    }

    /// A notice from the last session (nothing heard, recognizer died) outranks "Tap to talk".
    @Test func aNoticeIsShownOverTheIdlePrompt() {
        #expect(VoiceBarState.prompt(isListening: false, isThinking: false, availability: .ready, notice: "Didn't catch that.")
                == .blocked("Didn't catch that."))
    }

    /// Listening wins over a stale notice, so the bar never nags mid-session.
    @Test func listeningClearsTheNotice() {
        #expect(VoiceBarState.prompt(isListening: true, isThinking: false, availability: .ready, notice: "Didn't catch that.")
                == .listening)
    }

    @Test func theMicIsTappableUnlessItCannotWork() {
        #expect(VoiceBarState.isMicEnabled(availability: .ready, isThinking: false) == true)
        #expect(VoiceBarState.isMicEnabled(availability: .needsPermission, isThinking: false) == true)
        #expect(VoiceBarState.isMicEnabled(availability: .denied, isThinking: false) == false)
        #expect(VoiceBarState.isMicEnabled(availability: .unsupported, isThinking: false) == false)
        // Mid-parse, a second tap would race the first.
        #expect(VoiceBarState.isMicEnabled(availability: .ready, isThinking: true) == false)
    }
}
