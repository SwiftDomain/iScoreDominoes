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

struct CollectionView: View {
    var ids = ["5ie29kq1fGk", "jxpyqdb_SkE", "cBYp7iRKQ-o", "AeaerQ2hxTQ", "H-Y1E-CSMPE"]
    var body: some View {
        ZStack {
            
            Background()
            
            Image("cover")
                .resizable().opacity(0.2)
            ScrollView(showsIndicators: false) {
                VStack {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 250, height: 50)
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 11)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 18, height: 18)))
                        .opacity(0.02)
                        .overlay(
                            Text("Tutorial")
                                .foregroundStyle(.accent)
                                .fontWeight(.light)
                                .minimumScaleFactor(0.75)
                                .font(.largeTitle)
                                .shadow(color: .white, radius: 25)
                        )
                    
                    ForEach(ids, id:\.self) {idData in
                        YouTubeView(videoId: idData)
                            .frame(width: 300, height: 300)
                            .padding()
                            .glassEffectTransition(.materialize)
                    }
                }
            }
            
        }
    }
}

#Preview {
    CollectionView()
}
