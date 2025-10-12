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
    
    // Calculate time value for animation
    private var timeValue: Double {
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        
        let hour = localCalendar.component(.hour, from: date)
        let minute = localCalendar.component(.minute, from: date)
        return Double(hour) + Double(minute) / 60.0
    }
    
    // Calculate star visibility based on time of day
    private var starOpacity: Double {
        let normalizedTime = timeValue.truncatingRemainder(dividingBy: 24)
        
        switch normalizedTime {
        case 0..<4:
            // Deep night - full stars
            return 1.0
        case 4..<5:
            // Astronomical twilight - stars fading
            let progress = (normalizedTime - 4)
            return 1.0 - (progress * 0.3)
        case 5..<6:
            // Nautical twilight - stars mostly faded
            let progress = (normalizedTime - 5)
            return 0.7 - (progress * 0.5)
        case 6..<7:
            // Civil twilight - stars barely visible
            let progress = (normalizedTime - 6)
            return 0.2 - (progress * 0.2)
        case 7..<19:
            // Daytime - no stars
            return 0.0
        case 19..<20:
            // Evening civil twilight - stars appearing
            let progress = (normalizedTime - 19)
            return progress * 0.2
        case 20..<21:
            // Nautical twilight - stars becoming visible
            let progress = (normalizedTime - 20)
            return 0.2 + (progress * 0.5)
        case 21..<22:
            // Astronomical twilight - stars brightening
            let progress = (normalizedTime - 21)
            return 0.7 + (progress * 0.3)
        default:
            // Late night (22:00 - 24:00) - full stars
            return 1.0
        }
    }
    
    // Calculate physically accurate sky colors based on atmospheric scattering
    private var skyGradient: LinearGradient {
        
        // Define colors for different times of day based on physical sky observations
        let colors: [Color]
        let startPoint = UnitPoint.top
        let endPoint = UnitPoint.bottom
        
        // Use more gradual transitions with interpolation
        let normalizedTime = timeValue.truncatingRemainder(dividingBy: 24)
        
        switch normalizedTime {
        case 0..<4:
            // Night (0:00 - 4:00) - Very dark blue to black
            let progress = normalizedTime / 4
            colors = [
                Color(red: 0.01, green: 0.01, blue: 0.05 + 0.03 * (1 - progress)),
                Color(red: 0.02, green: 0.02, blue: 0.08 + 0.04 * (1 - progress)),
                Color(red: 0.03, green: 0.03, blue: 0.12 + 0.06 * (1 - progress))
            ]
            
        case 4..<5:
            // Astronomical twilight (4:00 - 5:00) - Deep blue beginning
            let progress = (normalizedTime - 4)
            colors = [
                Color(red: 0.03 + 0.05 * progress, green: 0.03 + 0.05 * progress, blue: 0.12 + 0.18 * progress),
                Color(red: 0.05 + 0.07 * progress, green: 0.05 + 0.07 * progress, blue: 0.18 + 0.22 * progress),
                Color(red: 0.07 + 0.1 * progress, green: 0.07 + 0.08 * progress, blue: 0.25 + 0.25 * progress)
            ]
            
        case 5..<6:
            // Nautical twilight (5:00 - 6:00) - Deep blue with purple hints
            let progress = (normalizedTime - 5)
            colors = [
                Color(red: 0.08 + 0.12 * progress, green: 0.08 + 0.07 * progress, blue: 0.3 + 0.15 * progress),
                Color(red: 0.12 + 0.18 * progress, green: 0.12 + 0.08 * progress, blue: 0.4 + 0.1 * progress),
                Color(red: 0.17 + 0.23 * progress, green: 0.15 + 0.05 * progress, blue: 0.5)
            ]
            
        case 6..<7:
            // Civil twilight / Dawn (6:00 - 7:00) - Blue hour with warm horizon
            let progress = (normalizedTime - 6)
            colors = [
                Color(red: 0.2 + 0.15 * progress, green: 0.15 + 0.25 * progress, blue: 0.45 + 0.25 * progress),
                Color(red: 0.3 + 0.2 * progress, green: 0.2 + 0.3 * progress, blue: 0.5 + 0.3 * progress),
                Color(red: 0.4 + 0.3 * progress, green: 0.2 + 0.2 * progress, blue: 0.5 + 0.2 * progress),
                Color(red: 0.6 + 0.3 * progress, green: 0.35 + 0.15 * progress, blue: 0.4 + 0.1 * progress)
            ]
            
        case 7..<8:
            // Sunrise (7:00 - 8:00) - Golden/orange to blue transition
            let progress = (normalizedTime - 7)
            colors = [
                Color(red: 0.35 + 0.05 * progress, green: 0.4 + 0.3 * progress, blue: 0.7 + 0.2 * progress),
                Color(red: 0.5 - 0.05 * progress, green: 0.5 + 0.25 * progress, blue: 0.8 + 0.15 * progress),
                Color(red: 0.7 - 0.15 * progress, green: 0.55 + 0.2 * progress, blue: 0.7 + 0.2 * progress),
                Color(red: 0.9 - 0.3 * progress, green: 0.5 + 0.2 * progress, blue: 0.5 + 0.3 * progress)
            ]
            
        case 8..<11:
            // Morning (8:00 - 11:00) - Clear blue sky
            let progress = (normalizedTime - 8) / 3
            colors = [
                Color(red: 0.4 - 0.1 * progress, green: 0.7 - 0.05 * progress, blue: 0.9),
                Color(red: 0.45 - 0.1 * progress, green: 0.75 - 0.05 * progress, blue: 0.95),
                Color(red: 0.55 - 0.15 * progress, green: 0.8 - 0.1 * progress, blue: 1.0)
            ]
            
        case 11..<14:
            // Noon (11:00 - 14:00) - Deep blue (zenith), less atmospheric scattering
            colors = [
                Color(red: 0.3, green: 0.65, blue: 0.9),
                Color(red: 0.35, green: 0.7, blue: 0.95),
                Color(red: 0.4, green: 0.75, blue: 1.0)
            ]
            
        case 14..<17:
            // Afternoon (14:00 - 17:00) - Slightly warmer blue
            let progress = (normalizedTime - 14) / 3
            colors = [
                Color(red: 0.3 + 0.1 * progress, green: 0.65, blue: 0.9 - 0.05 * progress),
                Color(red: 0.35 + 0.15 * progress, green: 0.7 + 0.05 * progress, blue: 0.95 - 0.05 * progress),
                Color(red: 0.4 + 0.2 * progress, green: 0.75 + 0.05 * progress, blue: 1.0 - 0.1 * progress)
            ]
            
        case 17..<18:
            // Golden hour beginning (17:00 - 18:00)
            let progress = (normalizedTime - 17)
            colors = [
                Color(red: 0.4 + 0.1 * progress, green: 0.65 + 0.05 * progress, blue: 0.85 - 0.15 * progress),
                Color(red: 0.5 + 0.2 * progress, green: 0.75 - 0.05 * progress, blue: 0.9 - 0.2 * progress),
                Color(red: 0.6 + 0.3 * progress, green: 0.8 - 0.15 * progress, blue: 0.9 - 0.3 * progress),
                Color(red: 0.8 + 0.15 * progress, green: 0.7 - 0.1 * progress, blue: 0.5 - 0.1 * progress)
            ]
            
        case 18..<19:
            // Sunset (18:00 - 19:00) - Full golden hour
            let progress = (normalizedTime - 18)
            colors = [
                Color(red: 0.5, green: 0.7 - 0.2 * progress, blue: 0.7 - 0.1 * progress),
                Color(red: 0.7 + 0.2 * progress, green: 0.7 - 0.15 * progress, blue: 0.7 - 0.2 * progress),
                Color(red: 0.9 + 0.05 * progress, green: 0.65 - 0.15 * progress, blue: 0.6 - 0.2 * progress),
                Color(red: 0.95 + 0.05 * progress, green: 0.6 - 0.2 * progress, blue: 0.4 - 0.15 * progress),
                Color(red: 1.0, green: 0.5 - 0.1 * progress, blue: 0.25 - 0.05 * progress)
            ]
            
        case 19..<20:
            // Civil twilight / Blue hour (19:00 - 20:00)
            let progress = (normalizedTime - 19)
            colors = [
                Color(red: 0.5 - 0.3 * progress, green: 0.5 - 0.25 * progress, blue: 0.6 + 0.1 * progress),
                Color(red: 0.6 - 0.4 * progress, green: 0.4 - 0.2 * progress, blue: 0.5 + 0.15 * progress),
                Color(red: 0.7 - 0.5 * progress, green: 0.35 - 0.2 * progress, blue: 0.4 + 0.2 * progress),
                Color(red: 0.4 - 0.25 * progress, green: 0.2 - 0.1 * progress, blue: 0.25 + 0.25 * progress)
            ]
            
        case 20..<21:
            // Nautical twilight (20:00 - 21:00)
            let progress = (normalizedTime - 20)
            colors = [
                Color(red: 0.2 - 0.1 * progress, green: 0.25 - 0.15 * progress, blue: 0.7 - 0.3 * progress),
                Color(red: 0.2 - 0.12 * progress, green: 0.2 - 0.12 * progress, blue: 0.65 - 0.35 * progress),
                Color(red: 0.15 - 0.1 * progress, green: 0.15 - 0.1 * progress, blue: 0.6 - 0.4 * progress)
            ]
            
        default:
            // Astronomical twilight to Night (21:00 - 24:00)
            let progress = min((normalizedTime - 21) / 3, 1)
            colors = [
                Color(red: 0.1 - 0.08 * progress, green: 0.1 - 0.08 * progress, blue: 0.4 - 0.28 * progress),
                Color(red: 0.08 - 0.06 * progress, green: 0.08 - 0.06 * progress, blue: 0.3 - 0.18 * progress),
                Color(red: 0.05 - 0.04 * progress, green: 0.05 - 0.04 * progress, blue: 0.2 - 0.12 * progress)
            ]
        }
        
        // Apply opacity to all colors for background usage
        let backgroundColors = colors.map { $0.opacity(0.65) } // Opacity
        
        return LinearGradient(
            colors: backgroundColors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    var body: some View {
        ZStack {
            // Background sky gradient
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(skyGradient)
                .blendMode(.plusLighter)
                .animation(.spring(), value: Int(timeValue * 4))
            
            // Stars overlay for nighttime
            if starOpacity > 0 {
                StarsView()
                    .opacity(starOpacity)
                    .blendMode(.plusLighter)
                    .animation(.spring(), value: starOpacity)
                    .allowsHitTesting(false)
            }
        }
    }
}
