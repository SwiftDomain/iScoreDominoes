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
        #expect(denied == .blocked(VoiceSetup.scoringExplanation(availability: .denied, error: nil)!))
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

    /// The idle mic is not a bare glyph: a host that draws the bar's text gets
    /// words for it, and they are short enough not to crowd the row.
    @Test func theIdleMicStillSaysWhatItIs() {
        let idle = VoiceBarState.Report(prompt: .tapToTalk, transcript: "")
        #expect(idle.line?.isEmpty == false)
        #expect(idle.isLive == false)
    }

    /// A session under way must outrank a finished one, or the last answer
    /// blanks the next "Listening…" for as long as its notice survives.
    @Test func aSessionInFlightReportsItself() {
        #expect(VoiceBarState.Report(prompt: .listening, transcript: "forty for us").isLive)
        #expect(VoiceBarState.Report(prompt: .listening, transcript: "forty for us").line?.contains("forty for us") == true)
        #expect(VoiceBarState.Report(prompt: .thinking, transcript: "").isLive)
        #expect(VoiceBarState.Report(prompt: .blocked("Mic is off"), transcript: "").isLive == false)
        #expect(VoiceBarState.Report.idleAway == VoiceBarState.Report(line: nil, isLive: false))
    }

    /// The bar's fallback is the keypad, not typing a sentence.
    @Test func aBlockedMicPointsAtTheKeypad() {
        for availability in [SpeechAvailability.denied, .unsupported, .needsPermission] {
            let text = VoiceSetup.scoringExplanation(availability: availability, error: nil)
            #expect(text?.contains("keypad") == true, "\(availability)")
            #expect(text?.contains("type the game") == false, "\(availability)")
        }
    }

    /// The most common blocked case: the mic heard nothing. The way out is the keypad.
    @Test func aSilentSessionPointsAtTheKeypad() {
        let text = VoiceSetup.scoringNotice(heard: "  ", availability: .ready, lastError: nil)
        #expect(text?.contains("keypad") == true)
        #expect(text?.contains("type the game") == false)
    }
}
