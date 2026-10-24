import Foundation
import Testing
@testable import iScore

struct LanguageRelaunchTests {

    private func emptyDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func onlyAnActualChangeNeedsARelaunch() {
        #expect(!LanguageRelaunch.needsRelaunch(changing: .english, to: .english))
        #expect(!LanguageRelaunch.needsRelaunch(changing: .spanish, to: .spanish))
        #expect(LanguageRelaunch.needsRelaunch(changing: .english, to: .spanish))
        #expect(LanguageRelaunch.needsRelaunch(changing: .spanish, to: .english))
    }

    @Test func applyWritesTheLanguageOverride() {
        let defaults = emptyDefaults("LanguageRelaunchTests.apply")
        defer { defaults.removePersistentDomain(forName: "LanguageRelaunchTests.apply") }
        LanguageRelaunch.apply(.spanish, to: defaults)
        #expect(defaults.stringArray(forKey: LanguageRelaunch.overrideKey)?.first == "es")
        #expect(defaults.string(forKey: LanguageSettings.appKey) == "es")
    }

    /// The override and the app's own stored value must not drift apart: the
    /// picker reads one and the bundle reads the other.
    @Test func applyKeepsTheOverrideAndTheStoredValueInStep() {
        let defaults = emptyDefaults("LanguageRelaunchTests.step")
        defer { defaults.removePersistentDomain(forName: "LanguageRelaunchTests.step") }
        LanguageRelaunch.apply(.spanish, to: defaults)
        LanguageRelaunch.apply(.english, to: defaults)
        #expect(defaults.stringArray(forKey: LanguageRelaunch.overrideKey)?.first == "en")
        #expect(LanguageSettings.app(from: defaults) == .english)
    }
}
