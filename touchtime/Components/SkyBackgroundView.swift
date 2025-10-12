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
    
    // Calculate the color based on the time of day
    private var skyGradient: LinearGradient {
        
        // Define colors for different times of day (same as SkyDotView)
        let colors: [Color]
        let startPoint = UnitPoint.top
        let endPoint = UnitPoint.bottom
        
        // Use more gradual transitions with interpolation
        let normalizedTime = timeValue.truncatingRemainder(dividingBy: 24)
        
        switch normalizedTime {
        case 0..<3:
            // Deep night (0:00 - 3:00)
            colors = [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.08, green: 0.08, blue: 0.2)
            ]
        case 3..<5:
            // Late night to early dawn (3:00 - 5:00)
            let progress = (normalizedTime - 3) / 2
            colors = [
                Color(red: 0.05 + 0.1 * progress, green: 0.05 + 0.1 * progress, blue: 0.15 + 0.2 * progress),
                Color(red: 0.1 + 0.15 * progress, green: 0.1 + 0.1 * progress, blue: 0.25 + 0.15 * progress)
            ]
        case 5..<6.5:
            // Dawn approaching (5:00 - 6:30)
            let progress = (normalizedTime - 5) / 1.5
            colors = [
                Color(red: 0.15 + 0.25 * progress, green: 0.15 + 0.15 * progress, blue: 0.35 + 0.15 * progress),
                Color(red: 0.25 + 0.35 * progress, green: 0.2 + 0.2 * progress, blue: 0.4 + 0.1 * progress),
                Color(red: 0.3 + 0.5 * progress, green: 0.25 + 0.25 * progress, blue: 0.35 + 0.05 * progress)
            ]
        case 6.5..<8:
            // Sunrise (6:30 - 8:00)
            let progress = (normalizedTime - 6.5) / 1.5
            colors = [
                Color(red: 0.6 + 0.3 * progress, green: 0.4 + 0.3 * progress, blue: 0.5 + 0.1 * progress),
                Color(red: 0.8 + 0.2 * progress, green: 0.5 + 0.3 * progress, blue: 0.5 + 0.2 * progress),
                Color(red: 0.9 + 0.1 * progress, green: 0.6 + 0.3 * progress, blue: 0.4 + 0.4 * progress)
            ]
        case 8..<12:
            // Morning to noon (8:00 - 12:00)
            let progress = (normalizedTime - 8) / 4
            colors = [
                Color(red: 0.5 - 0.1 * progress, green: 0.7 - 0.1 * progress, blue: 0.95 - 0.05 * progress),
                Color(red: 0.6 - 0.1 * progress, green: 0.8 - 0.1 * progress, blue: 1.0 - 0.05 * progress),
                Color(red: 0.7 - 0.1 * progress, green: 0.85 - 0.1 * progress, blue: 1.0 - 0.05 * progress)
            ]
        case 12..<15:
            // Afternoon (12:00 - 15:00)
            colors = [
                Color(red: 0.4, green: 0.6, blue: 0.9),
                Color(red: 0.5, green: 0.7, blue: 0.95),
                Color(red: 0.6, green: 0.75, blue: 0.95)
            ]
        case 15..<17:
            // Late afternoon (15:00 - 17:00)
            let progress = (normalizedTime - 15) / 2
            colors = [
                Color(red: 0.4 + 0.4 * progress, green: 0.6 + 0.1 * progress, blue: 0.9 - 0.3 * progress),
                Color(red: 0.5 + 0.4 * progress, green: 0.7 + 0.05 * progress, blue: 0.95 - 0.45 * progress),
                Color(red: 0.6 + 0.4 * progress, green: 0.75 + 0.05 * progress, blue: 0.95 - 0.45 * progress)
            ]
        case 17..<19:
            // Sunset (17:00 - 19:00)
            let progress = (normalizedTime - 17) / 2
            colors = [
                Color(red: 0.8 + 0.1 * progress, green: 0.7 - 0.2 * progress, blue: 0.6 - 0.3 * progress),
                Color(red: 0.9 + 0.05 * progress, green: 0.75 - 0.15 * progress, blue: 0.5 - 0.1 * progress),
                Color(red: 1.0, green: 0.8 - 0.1 * progress, blue: 0.5)
            ]
        case 19..<21:
            // Dusk to evening (19:00 - 21:00)
            let progress = (normalizedTime - 19) / 2
            colors = [
                Color(red: 0.5 - 0.3 * progress, green: 0.3 - 0.15 * progress, blue: 0.4),
                Color(red: 0.4 - 0.25 * progress, green: 0.25 - 0.15 * progress, blue: 0.5 - 0.15 * progress),
                Color(red: 0.3 - 0.2 * progress, green: 0.2 - 0.12 * progress, blue: 0.6 - 0.3 * progress)
            ]
        default:
            // Night (21:00 - 24:00)
            let progress = min((normalizedTime - 21) / 3, 1)
            colors = [
                Color(red: 0.2 - 0.12 * progress, green: 0.15 - 0.07 * progress, blue: 0.4 - 0.2 * progress),
                Color(red: 0.15 - 0.1 * progress, green: 0.1 - 0.05 * progress, blue: 0.35 - 0.2 * progress)
            ]
        }
        
        // Apply opacity to all colors for background usage
        let backgroundColors = colors.map { $0.opacity(0.50) }
        
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
