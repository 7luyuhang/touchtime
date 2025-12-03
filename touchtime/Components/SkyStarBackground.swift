//
//  SkyBackgroundView.swift
//  touchtime
//
//  Created for background usage
//

import SwiftUI

// Star particle view for night sky
struct StarParticle: View {
    let size: CGFloat
    let twinkleDelay: Double
    let twinkleDuration: Double
    @State private var isTwinkling = false
    
    // Calculate target opacity based on star size
    private var targetOpacity: Double {
        if size > 1.5 {
            return 0.3  // Bright stars twinkle to 30% opacity
        } else if size > 0.8 {
            return 0.2  // Medium stars twinkle to 20% opacity
        } else {
            return 0.1  // Small stars twinkle to 10% opacity
        }
    }
    
    var body: some View {
        Circle()
            .fill(
                // Add slight color variation for more realistic stars
                size > 1.5 ? 
                Color(white: 1.0) :  // Bright stars are pure white
                Color(white: 0.95, opacity: 1.0)  // Smaller stars slightly dimmer
            )
            .frame(width: size, height: size)
            .opacity(isTwinkling ? targetOpacity : 1.0)
            .blur(radius: size > 1.5 ? 0.3 : 0)
            .shadow(color: Color(white: 0.9).opacity(isTwinkling ? 0.3 : 0.9), radius: size > 1.2 ? 3 : 1)  // Dynamic glow
            .animation(
                Animation.spring(duration: twinkleDuration)
                    .repeatForever(autoreverses: true)
                    .delay(twinkleDelay),
                value: isTwinkling
            )
            .onAppear {
                isTwinkling = true
            }
    }
}

// Container for multiple stars
struct StarsView: View {
    var starCount: Int = 50  // Number of stars (configurable)
    @State private var stars: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, twinkleDelay: Double, twinkleDuration: Double)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars, id: \.id) { star in
                    StarParticle(
                        size: star.size,
                        twinkleDelay: star.twinkleDelay,
                        twinkleDuration: star.twinkleDuration
                    )
                    .position(x: star.x, y: star.y)
                }
            }
            .onAppear {
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    generateStars(in: geometry.size)
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                // Regenerate stars when size changes from zero to valid size
                if stars.isEmpty && newSize.width > 0 && newSize.height > 0 {
                    generateStars(in: newSize)
                }
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
        var newStars: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, twinkleDelay: Double, twinkleDuration: Double)] = []
        
        for i in 0..<starCount {
            // Create different star types
            let starType = Double.random(in: 0...1)
            let starSize: CGFloat
            let twinkleDuration: Double
            
            if starType < 0.75 {  // 75% small dim stars
                starSize = CGFloat.random(in: 0.4...0.8)
                twinkleDuration = Double.random(in: 1.0...2.0)  // Faster twinkle for more noticeable effect
            } else if starType < 0.97 {  // 22% medium stars
                starSize = CGFloat.random(in: 0.8...1.4)
                twinkleDuration = Double.random(in: 0.8...1.8)  // Faster twinkle
            } else {  // 3% bright stars
                starSize = CGFloat.random(in: 1.5...2.5)  // Bigger bright stars
                twinkleDuration = Double.random(in: 0.6...1.5)  // Fastest twinkle for bright stars
            }
            
            newStars.append((
                id: i,
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: starSize,
                twinkleDelay: Double.random(in: 0...3),
                twinkleDuration: twinkleDuration
            ))
        }
        stars = newStars
    }
}

struct SkyBackgroundView: View {
    let date: Date
    let timeZoneIdentifier: String
    
    // Create sky color gradient instance
    private var skyColorGradient: SkyColorGradient {
        SkyColorGradient(date: date, timeZoneIdentifier: timeZoneIdentifier)
    }
    
    var body: some View {
        ZStack {
            // Background sky gradient with opacity for background usage
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(skyColorGradient.linearGradient(opacity: 0.65))
                .animation(.spring(), value: skyColorGradient.animationValue)
            
            // Stars overlay for nighttime
            if skyColorGradient.starOpacity > 0 {
                StarsView()
                    .opacity(skyColorGradient.starOpacity)
                    .blendMode(.plusLighter)
                    .animation(.spring(), value: skyColorGradient.starOpacity)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // border
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1.0)
                .blendMode(.plusLighter)
        )
    }
}