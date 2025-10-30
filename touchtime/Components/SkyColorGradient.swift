//
//  SkyColorGradient.swift
//  touchtime
//
//  Shared sky gradient colors based on time of day
//

import SwiftUI

struct SkyColorGradient {
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
    var starOpacity: Double {
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
    
    // Get the colors array based on time
    var colors: [Color] {
        let normalizedTime = timeValue.truncatingRemainder(dividingBy: 24)
        
        switch normalizedTime {
        case 0..<4:
            // Night (0:00 - 4:00) - Very dark blue to black
            let progress = normalizedTime / 4
            return [
                Color(red: 0.01, green: 0.01, blue: 0.05 + 0.03 * (1 - progress)),
                Color(red: 0.02, green: 0.02, blue: 0.08 + 0.04 * (1 - progress)),
                Color(red: 0.03, green: 0.03, blue: 0.12 + 0.06 * (1 - progress))
            ]
            
        case 4..<5:
            // Astronomical twilight (4:00 - 5:00) - Deep blue beginning
            let progress = (normalizedTime - 4)
            return [
                // Zenith: Darkest blue, minimal red/green to avoid purple
                Color(red: 0.03 + 0.02 * progress, green: 0.03 + 0.03 * progress, blue: 0.12 + 0.20 * progress),
                // Mid-sky: Slightly lighter blue, maintaining blue dominance
                Color(red: 0.04 + 0.03 * progress, green: 0.04 + 0.04 * progress, blue: 0.18 + 0.24 * progress),
                // Horizon: Brighter blue with very subtle warm undertone from atmospheric scattering
                Color(red: 0.05 + 0.04 * progress, green: 0.05 + 0.05 * progress, blue: 0.25 + 0.27 * progress),
                // Near horizon: Slightly warmer but still predominantly blue
                Color(red: 0.06 + 0.06 * progress, green: 0.06 + 0.06 * progress, blue: 0.28 + 0.25 * progress)
            ]
            
        case 5..<6:
            // Nautical twilight (5:00 - 6:00) - Deep blue with purple hints
            let progress = (normalizedTime - 5)
            return [
                Color(red: 0.08 + 0.12 * progress, green: 0.08 + 0.07 * progress, blue: 0.3 + 0.15 * progress),
                Color(red: 0.12 + 0.18 * progress, green: 0.12 + 0.08 * progress, blue: 0.4 + 0.1 * progress),
                Color(red: 0.17 + 0.23 * progress, green: 0.15 + 0.05 * progress, blue: 0.5)
            ]
            
        case 6..<7:
            // Civil twilight / Dawn (6:00 - 7:00) - Blue hour with warm horizon
            let progress = (normalizedTime - 6)
            return [
                Color(red: 0.2 + 0.15 * progress, green: 0.15 + 0.25 * progress, blue: 0.45 + 0.25 * progress),
                Color(red: 0.3 + 0.2 * progress, green: 0.2 + 0.3 * progress, blue: 0.5 + 0.3 * progress),
                Color(red: 0.4 + 0.3 * progress, green: 0.2 + 0.2 * progress, blue: 0.5 + 0.2 * progress),
                Color(red: 0.6 + 0.3 * progress, green: 0.35 + 0.15 * progress, blue: 0.4 + 0.1 * progress)
            ]
            
        case 7..<8:
            // Sunrise (7:00 - 8:00) - Golden/orange to blue transition
            let progress = (normalizedTime - 7)
            return [
                Color(red: 0.35 + 0.05 * progress, green: 0.4 + 0.3 * progress, blue: 0.7 + 0.2 * progress),
                Color(red: 0.5 - 0.05 * progress, green: 0.5 + 0.25 * progress, blue: 0.8 + 0.15 * progress),
                Color(red: 0.7 - 0.15 * progress, green: 0.55 + 0.2 * progress, blue: 0.7 + 0.2 * progress),
                Color(red: 0.9 - 0.3 * progress, green: 0.5 + 0.2 * progress, blue: 0.5 + 0.3 * progress)
            ]
            
        case 8..<11:
            // Morning (8:00 - 11:00) - Clear blue sky with bright horizon
            let progress = (normalizedTime - 8) / 3
            return [
                Color(red: 0.4 - 0.1 * progress, green: 0.7 - 0.05 * progress, blue: 0.9),  // Deep blue at zenith
                Color(red: 0.45 - 0.1 * progress, green: 0.75 - 0.05 * progress, blue: 0.95),  // Mid sky
                Color(red: 0.6 - 0.1 * progress, green: 0.8 - 0.05 * progress, blue: 0.98),  // Lower sky
                Color(red: 0.75 + 0.1 * progress, green: 0.85 + 0.05 * progress, blue: 0.95)  // Near horizon - whiter due to atmospheric scattering
            ]
            
        case 11..<14:
            // Noon (11:00 - 14:00) - Deep blue zenith with bright horizon
            return [
                Color(red: 0.3, green: 0.65, blue: 0.9),  // Deep blue at zenith
                Color(red: 0.35, green: 0.7, blue: 0.95),  // Mid sky
                Color(red: 0.5, green: 0.75, blue: 0.98),  // Lower sky
                Color(red: 0.85, green: 0.9, blue: 0.95)  // Near horizon - maximum brightness/whiteness
            ]
            
        case 14..<17:
            // Afternoon (14:00 - 17:00) - Slightly warmer blue with bright horizon
            let progress = (normalizedTime - 14) / 3
            return [
                Color(red: 0.3 + 0.1 * progress, green: 0.65, blue: 0.9 - 0.05 * progress),  // Zenith
                Color(red: 0.35 + 0.15 * progress, green: 0.7 + 0.05 * progress, blue: 0.95 - 0.05 * progress),  // Mid sky
                Color(red: 0.5 + 0.15 * progress, green: 0.75 + 0.05 * progress, blue: 0.98 - 0.08 * progress),  // Lower sky
                Color(red: 0.85 - 0.1 * progress, green: 0.9 - 0.1 * progress, blue: 0.95 - 0.15 * progress)  // Horizon - transitioning to golden hour
            ]
            
        case 17..<18:
            // Golden hour beginning (17:00 - 18:00)
            let progress = (normalizedTime - 17)
            return [
                Color(red: 0.4 + 0.1 * progress, green: 0.65 + 0.05 * progress, blue: 0.85 - 0.15 * progress),
                Color(red: 0.5 + 0.2 * progress, green: 0.75 - 0.05 * progress, blue: 0.9 - 0.2 * progress),
                Color(red: 0.6 + 0.3 * progress, green: 0.8 - 0.15 * progress, blue: 0.9 - 0.3 * progress),
                Color(red: 0.8 + 0.15 * progress, green: 0.7 - 0.1 * progress, blue: 0.5 - 0.1 * progress)
            ]
            
        case 18..<19:
            // Sunset (18:00 - 19:00) - Full golden hour
            let progress = (normalizedTime - 18)
            return [
                Color(red: 0.5, green: 0.7 - 0.2 * progress, blue: 0.7 - 0.1 * progress),
                Color(red: 0.7 + 0.2 * progress, green: 0.7 - 0.15 * progress, blue: 0.7 - 0.2 * progress),
                Color(red: 0.9 + 0.05 * progress, green: 0.65 - 0.15 * progress, blue: 0.6 - 0.2 * progress),
                Color(red: 0.95 + 0.05 * progress, green: 0.6 - 0.2 * progress, blue: 0.4 - 0.15 * progress),
                Color(red: 1.0, green: 0.5 - 0.1 * progress, blue: 0.25 - 0.05 * progress)
            ]
            
        case 19..<20:
            // Civil twilight / Blue hour (19:00 - 20:00)
            // Based on atmospheric Rayleigh scattering - deep blue with minimal red to avoid purple
            let progress = (normalizedTime - 19)
            return [
                // Zenith: Deep pure blue from Rayleigh scattering
                Color(red: 0.15 - 0.05 * progress, green: 0.25 - 0.1 * progress, blue: 0.65 - 0.15 * progress),
                // Upper sky: Slightly lighter blue
                Color(red: 0.18 - 0.08 * progress, green: 0.3 - 0.15 * progress, blue: 0.7 - 0.2 * progress),
                // Mid sky: Transitioning blue with hint of twilight
                Color(red: 0.25 - 0.15 * progress, green: 0.35 - 0.2 * progress, blue: 0.65 - 0.25 * progress),
                // Horizon: Last warm glow from scattered sunlight
                Color(red: 0.35 - 0.25 * progress, green: 0.3 - 0.2 * progress, blue: 0.5 - 0.2 * progress)
            ]
            
        case 20..<21:
            // Nautical twilight (20:00 - 21:00)
            // Sun is 6-12° below horizon - deep blue to dark indigo transition
            let progress = (normalizedTime - 20)
            return [
                // Zenith: Very dark blue transitioning to near-black
                Color(red: 0.1 - 0.07 * progress, green: 0.15 - 0.12 * progress, blue: 0.5 - 0.35 * progress),
                // Upper sky: Deep indigo blue
                Color(red: 0.1 - 0.08 * progress, green: 0.15 - 0.12 * progress, blue: 0.45 - 0.3 * progress),
                // Mid sky: Dark blue with faint twilight glow
                Color(red: 0.12 - 0.09 * progress, green: 0.15 - 0.12 * progress, blue: 0.4 - 0.28 * progress),
                // Horizon: Last traces of twilight, deep blue-grey
                Color(red: 0.15 - 0.12 * progress, green: 0.15 - 0.12 * progress, blue: 0.3 - 0.2 * progress)
            ]
            
        default:
            // Astronomical twilight to Night (21:00 - 24:00)
            let progress = min((normalizedTime - 21) / 3, 1)
            return [
                Color(red: 0.1 - 0.08 * progress, green: 0.1 - 0.08 * progress, blue: 0.4 - 0.28 * progress),
                Color(red: 0.08 - 0.06 * progress, green: 0.08 - 0.06 * progress, blue: 0.3 - 0.18 * progress),
                Color(red: 0.05 - 0.04 * progress, green: 0.05 - 0.04 * progress, blue: 0.2 - 0.12 * progress)
            ]
        }
    }
    
    // Get linear gradient with specified opacity (default 1.0 for full opacity)
    func linearGradient(opacity: Double = 1.0) -> LinearGradient {
        let gradientColors = opacity < 1.0 ? colors.map { $0.opacity(opacity) } : colors
        return LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Get the animation value for smooth transitions
    var animationValue: Int {
        return Int(timeValue * 4)
    }
}
