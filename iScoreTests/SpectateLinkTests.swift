import Foundation
import Testing
@testable import iScore

struct SpectateLinkTests {

    /// Without these the system refuses to browse or advertise at all.
    @Test func theBonjourServicesAreDeclared() {
        let services = Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String] ?? []
        #expect(services.contains("_\(SpectateService.type)._tcp"))
        #expect(services.contains("_\(SpectateService.type)._udp"))
    }

    @Test func theLocalNetworkPromptSaysWhy() {
        let reason = Bundle.main.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription") as? String
        #expect(reason?.isEmpty == false)
    }

    /// Bonjour's rule: 1–15 characters, lowercase letters, digits and hyphens.
    @Test func theServiceTypeIsAValidBonjourName() {
        let type = SpectateService.type
        #expect((1...15).contains(type.count))
        #expect(type.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" })
    }

    /// Every permission prompt reads in Spanish on a Spanish phone.
    @Test func thePermissionPromptsHaveSpanish() throws {
        let path = try #require(Bundle.main.path(forResource: "es", ofType: "lproj"))
        let spanish = try #require(Bundle(path: path))
        for key in ["NSLocalNetworkUsageDescription", "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"] {
            let english = Bundle.main.object(forInfoDictionaryKey: key) as? String
            let translated = spanish.localizedString(forKey: key, value: nil, table: "InfoPlist")
            #expect(translated != key)
            #expect(translated != english)
        }
    }

    /// MCPeerID raises past 63 UTF-8 bytes; an emoji or legacy name must
    /// never crash the app.
    @Test func thePeerNameAlwaysFitsMultipeer() {
        let long = String(repeating: "👨‍👩‍👧‍👦", count: 15)
        let fitted = SpectateService.fitted(long)
        #expect(fitted.utf8.count <= 63)
        #expect(!fitted.isEmpty)
        #expect(SpectateService.fitted("Ana") == "Ana")
        #expect(SpectateService.fitted("") == "iScore")
    }

    @MainActor @Test func aHostThatNeverStartedSendsNothing() {
        let link = SpectateHostLink()
        link.publish(makeTestGame())
        #expect(link.code == nil)
        #expect(link.sharedGameID == nil)
        #expect(link.watching == 0)
    }
}
