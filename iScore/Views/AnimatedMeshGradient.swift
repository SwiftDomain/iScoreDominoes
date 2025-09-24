//
//  AnimatedMeshGradient.swift
//  iScore
//
//  Created by BeastMode on 5/21/25.
//

import SwiftUI

struct AnimatedMeshGradient: View {
    
    @State var appear = false
    @State var appear2 = false
    
    var body: some View {
        
        MeshGradient (
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [appear2 ? 0.5 : 1.0, 0.0], [1.0, 0.0],
                [0.0, 0.5], appear ? [0.1, 0.5] : [0.8, 0.2], [1.0, -0.5],
                [0.0, 1.0], [1.0, appear2 ? 2.0 : 1.0], [1.0, 1.0]
            ], colors: [
                appear2 ? .red: .mint, appear2 ? .yellow : .cyan, .orange,
                appear ? .blue: .red, appear ? .cyan: .white, appear ? .red: .purple,
                appear ? .red: .cyan, appear ? .mint: .blue, appear2 ? .red : .blue
            ]
        )
        .mask(
            RoundedRectangle(cornerRadius: 16)
                .stroke(lineWidth: 10)
                .blur(radius: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(.white, lineWidth: 3)
            .blur(radius: 2)
            .blendMode(.overlay)
        )
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(.white, lineWidth: 1)
            .blur(radius: 1)
            .blendMode(.overlay)
            
        )
        .background(.clear)
        .cornerRadius(16)
        .background(RoundedRectangle(cornerRadius: 16)
            .stroke(.black.opacity(0.5), lineWidth: 1)
                    )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                appear.toggle()
            }
            withAnimation(.easeInOut (duration: 2).repeatForever(autoreverses: true)) {
                appear2.toggle()
            }
        }
    }
}

#Preview {
    AnimatedMeshGradient()
        .ignoresSafeArea()
}
