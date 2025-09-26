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
    GlowingCircularProgressBar(progress: 0.95, lineWidth: 9.0, size: 180 )
}


struct GlowingCircularProgressBar: View {
    var progress: Double   // 0.0 ... 1.0
    var lineWidth: CGFloat = 14
    var size: CGFloat = 140
    var gradient = AngularGradient(
        gradient: Gradient(colors: [.lightBlue, .darkBlue]),
        center: .center
    )
    
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: lineWidth))
            
            // Progress stroke with glow
            Circle()
                .trim(from: 0, to: CGFloat(clampedProgress))
                .stroke(gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.purple.opacity(0.6), radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.4), value: progress)
            
            // Percentage or checkmark
            if clampedProgress < 1.0 {
                Text("\(Int(clampedProgress * 100))%")
                    .font(.title2).bold()
                    .scaleEffect(pulse ? 1.1 : 1.0) // pulse
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .onAppear { pulse = true }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Text("\(Int(clampedProgress * 100)) percent"))
    }
    
    private var clampedProgress: Double {
        min(max(progress, 0.0), 1.0)
    }
}
