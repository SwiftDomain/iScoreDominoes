//
//  SwiftUIView.swift
//  iScore
//
//  Created by BeastMode on 9/24/25.
//

import SwiftUI

struct Glass: View {

    @State private var isExpanded: Bool = false
    @Namespace private var namespace


    var body: some View {
        
        ZStack{
            
            
            Background()
            
            
            VStack {
                GlassEffectContainer(spacing: 40.0) {
                    HStack(spacing: 40.0) {
                        Image(systemName: "scribble.variable")
                            .frame(width: 80.0, height: 80.0)
                            .font(.system(size: 36))
                            .glassEffect()
                            .glassEffectID("pencil", in: namespace)
                        
                        
                        if isExpanded {
                            Image(systemName: "eraser.fill")
                                .frame(width: 80.0, height: 80.0)
                                .font(.system(size: 36))
                                .glassEffect()
                                .glassEffectID("eraser", in: namespace)
                        }
                    }
                }
                
                Button("Toggle") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .buttonStyle(.glass)
            }
        }
    }
}

#Preview {
    Glass()
}
