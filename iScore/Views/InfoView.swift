//
//  InfoView.swift
//  iScore
//
//  Created by BeastMode on 3/6/24.
//

import SwiftUI
import WebKit

/// A YouTube video in an iframe. YouTube rejects embeds without an
/// identifying Referer ("Error 153"), so the page is loaded with the app's
/// own origin as its base URL, which WebKit sends as the Referer.
struct YouTubeView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        // Loaded once here, not in updateUIView, which runs on every view update.
        webView.loadHTMLString(Self.embedHTML(videoId: videoId), baseURL: Self.appOrigin())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// `https://<bundle id, lowercased>`, the Referer YouTube asks WebView apps to send.
    static func appOrigin(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> URL? {
        guard let bundleIdentifier else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = bundleIdentifier.lowercased()
        return components.url
    }

    static func embedHTML(videoId: String) -> String {
        var components = URLComponents(string: "https://www.youtube.com")
        components?.path = "/embed/\(videoId)"
        let src = components?.url?.absoluteString ?? ""
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html, body { margin: 0; height: 100%; overflow: hidden; }
        iframe { display: block; width: 100%; height: 100%; border: 0; }
        </style>
        </head>
        <body>
        <iframe src="\(src)" title="YouTube video player" \
        allow="autoplay; encrypted-media; picture-in-picture; web-share" \
        referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
        </body>
        </html>
        """
    }
}

/// How to play: tutorial videos, each in a white card.
struct CollectionView: View {

    var ids = ["5ie29kq1fGk", "jxpyqdb_SkE", "cBYp7iRKQ-o", "AeaerQ2hxTQ", "H-Y1E-CSMPE"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader()

                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.surface)
                        .frame(width: 52, height: 52)
                        .duoSolid(fill: Theme.learn, edge: Theme.learnShadow, radius: 16)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("How to play")
                            .font(DuoFont.title)
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Short videos on the rules and scoring")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .padding(.bottom, 4)

                ForEach(Array(ids.enumerated()), id: \.element) { index, videoId in
                    VStack(alignment: .leading, spacing: 0) {
                        YouTubeView(videoId: videoId)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 11))

                        Text("Video \(index + 1)")
                            .duoLabel()
                            .padding(.horizontal, 6)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                    .padding(6)
                    .duoCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
    }
}

#Preview {
    CollectionView()
        .fontDesign(.rounded)
}
