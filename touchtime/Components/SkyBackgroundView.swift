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
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Circle()
            .fill(
                // Add slight color variation for more realistic stars
                size > 1.5 ? 
                Color(white: 1.0) :  // Bright stars are pure white
                Color(white: 0.95, opacity: 1.0)  // Smaller stars slightly dimmer
            )
            .frame(width: size, height: size)
            .opacity(opacity)
            .blur(radius: size > 1.5 ? 0.3 : 0)
            .shadow(color: Color(white: 0.9).opacity(opacity), radius: size > 1.2 ? 3 : 1)  // Dynamic glow
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: twinkleDuration)
                        .repeatForever(autoreverses: true)
                        .delay(twinkleDelay)
                ) {
                    opacity = Double.random(in: 0.1...0.5)  // More dramatic opacity change
                }
            }
    }
}

// Container for multiple stars
struct StarsView: View {
    let starCount: Int = 30  // Number of stars
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
                generateStars(in: geometry.size)
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
                .blendMode(.plusLighter)
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
    }
}
