import Testing
@testable import iScore

/// YouTube rejects embeds that arrive without an identifying Referer
/// ("Error 153"). How to play loads each video in an iframe page whose base
/// URL is the app's own origin, which WebKit then sends as the Referer.
struct YouTubeEmbedTests {

    /// YouTube's guidance for WebViews: `https://` + the lowercased bundle ID.
    @Test func appOriginIsTheLowercasedBundleID() {
        #expect(YouTubeView.appOrigin(bundleIdentifier: "SwiftDomainUI.iScore")?.absoluteString == "https://swiftdomainui.iscore")
    }

    @Test func appOriginDefaultsToTheAppBundle() {
        #expect(YouTubeView.appOrigin()?.absoluteString == "https://swiftdomainui.iscore")
    }

    @Test func embedPageLoadsTheVideoInAnIframe() {
        let html = YouTubeView.embedHTML(videoId: "5ie29kq1fGk")
        #expect(html.contains(#"<iframe src="https://www.youtube.com/embed/5ie29kq1fGk""#))
        #expect(html.contains(#"referrerpolicy="strict-origin-when-cross-origin""#))
    }
}
