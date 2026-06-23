//
//  EarthImageView.swift
//  touchtime
//
//  Created by yuhang on 05/10/2025.
//

import SwiftUI

struct EarthImageView: View {
    @State private var scrollOffset: CGFloat = -128
    @Environment(\.scenePhase) private var scenePhase
    
    let imageWidth: CGFloat = 128
    let circleSize: CGFloat = 64
    
    /// Starts (or restarts) the seamless looping rotation.
    ///
    /// Resetting to `-128` is visually seamless because the WorldMap is tiled 3×
    /// at `imageWidth` 128, so offset `-128` and `0` render identically. This also
    /// re-arms the animation, which `.repeatForever` loses when the app is
    /// backgrounded and never resumes on its own.
    private func startRotation() {
        scrollOffset = -128
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            scrollOffset = 0
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.tertiary)
            
            ZStack {
                HStack(spacing: 0) {
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                    
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                    
                    Image("WorldMap")
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth)
                        .colorMultiply(Color(.systemBackground))
                }
                .offset(x: scrollOffset)
                .drawingGroup()
            }
            .frame(width: circleSize, height: circleSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.tertiary, lineWidth: 0.5)
            )
            
            
        }
        .frame(width: 64, height: 64)
        // Only animate while visible (onDisappear stops it in lazy containers)
        // and re-arm when returning to the foreground.
        .onAppear { startRotation() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { startRotation() }
        }
    }
}


#Preview {
    EarthImageView()
}
