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
            
            ScrollView(showsIndicators: false) {
                
                ForEach(ids, id:\.self) {idData in
                    YouTubeView(videoId: idData)
                        .frame(width: 300, height: 300)
                        .padding()
                }                    }
            .ignoresSafeArea(edges: .top)
            
            VStack{
                
                Spacer()

                Text("Tutorial")
                    .padding(20)
                    .glassEffect(.clear)
                    .foregroundStyle(.accent)
                    .fontWeight(.light)
                    .font(.largeTitle)
                    .padding(.top, 60)
            }
            
            
        }
    }
    
}


#Preview {
    CollectionView()
}
