//
//  InfoView.swift
//  iScore
//
//  Created by BeastMode on 3/6/24.
//

import SwiftUI
import WebKit

struct YouTubeView: UIViewRepresentable {
    let videoId: String
    func makeUIView(context: Context) ->  WKWebView {
        return WKWebView()
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let demoURL = URL(string: "https://www.youtube.com/embed/\(videoId)") else { return }
        uiView.scrollView.isScrollEnabled = false
        uiView.load(URLRequest(url: demoURL))
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
