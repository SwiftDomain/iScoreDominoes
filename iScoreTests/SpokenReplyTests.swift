import AVFoundation
import Foundation
import Testing
@testable import iScore

struct SpokenReplyTests {

    @Test func speechIsOnUntilItIsTurnedOff() {
        let defaults = UserDefaults(suiteName: "SpokenReplyTests.\(UUID().uuidString)")!
        #expect(VoiceOutput.load(from: defaults) == true)
        defaults.set(false, forKey: VoiceOutput.speechKey)
        #expect(VoiceOutput.load(from: defaults) == false)
        defaults.set(true, forKey: VoiceOutput.speechKey)
        #expect(VoiceOutput.load(from: defaults) == true)
    }

    @Test func theSettingDecidesWhetherToSpeak() {
        #expect(VoiceOutput.shouldSpeak(isEnabled: true) == true)
        #expect(VoiceOutput.shouldSpeak(isEnabled: false) == false)
    }

    /// Review Focus 6: a reply with speech off must not throw, hang, or crash —
    /// the answer still reaches the screen through the caller.
    @Test @MainActor func sayingSomethingWithSpeechOffIsHarmless() {
        let reply = SpokenReply(locale: Locale(identifier: "en_US"))
        reply.say("Ana & Luis lead by 60", isEnabled: false)
        reply.stop()
    }

    /// The voice language is a parameter, so Feature 4 changes call sites, not this class.
    @Test @MainActor func aVoiceIsChosenForTheLocale() {
        #expect(SpokenReply.voice(for: Locale(identifier: "es_US"))?.language.hasPrefix("es") == true)
        #expect(SpokenReply.voice(for: Locale(identifier: "en_US"))?.language.hasPrefix("en") == true)
    }
}
