//
//  SkyBackgroundView.swift
//  touchtime
//
//  Created for background usage
//

import SwiftUI

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
        let backgroundColors = colors.map { $0.opacity(0.65) }
        
        return LinearGradient(
            colors: backgroundColors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(skyGradient)
            .blendMode(.plusLighter)
            .animation(.spring(), value: Int(timeValue * 4))
    }
}
