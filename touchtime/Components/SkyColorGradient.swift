//
//  SkyColorGradient.swift
//  touchtime
//
//  Shared sky gradient colors based on time of day
//

import SwiftUI
import SunKit
import CoreLocation

struct SkyColorGradient {
    let date: Date
    let timeZoneIdentifier: String
    
    // Cached normalized time value (calculated once during initialization)
    private let normalizedTime: Double
    
    // Cached sun event times (same for entire day)
    private struct SunEventTimes {
        let sunriseHour: Double
        let sunsetHour: Double
        let civilDawnHour: Double
        let civilDuskHour: Double
        let nauticalDawnHour: Double
        let nauticalDuskHour: Double
        let astronomicalDawnHour: Double
        let astronomicalDuskHour: Double
        let solarNoonHour: Double
    }
    
    // Static cache to avoid recalculating SunKit for the same day and timezone
    private static var sunTimesCache: [String: SunEventTimes] = [:]
    private static let cacheQueue = DispatchQueue(label: "SkyColorGradient.cache")
    
    // Initialize and calculate normalized time once
    init(date: Date, timeZoneIdentifier: String) {
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
        self.normalizedTime = SkyColorGradient.calculateNormalizedTimeWithCache(date: date, timeZoneIdentifier: timeZoneIdentifier)
    }
    
    // Get normalized time with caching (cached sun times per day, then fast calculation)
    private static func calculateNormalizedTimeWithCache(date: Date, timeZoneIdentifier: String) -> Double {
        // Create cache key based on day-level precision and timezone
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZoneIdentifier)_\(dayComponents.year ?? 0)_\(dayComponents.month ?? 0)_\(dayComponents.day ?? 0)"
        
        // Get or calculate sun event times (cached per day)
        let sunTimes = cacheQueue.sync {
            if let cached = sunTimesCache[cacheKey] {
                return cached
            }
            
            // Calculate sun event times once per day
            let times = calculateSunEventTimes(date: date, timeZoneIdentifier: timeZoneIdentifier)
            sunTimesCache[cacheKey] = times
            
            // Limit cache size (keep last 30 days)
            if sunTimesCache.count > 30 {
                let keysToRemove = Array(sunTimesCache.keys.prefix(sunTimesCache.count - 30))
                for key in keysToRemove {
                    sunTimesCache.removeValue(forKey: key)
                }
            }
            
            return times
        }
        
        // Fast calculation using cached sun times
        return calculateNormalizedTimeFromSunTimes(date: date, timeZoneIdentifier: timeZoneIdentifier, sunTimes: sunTimes)
    }
    
    // Calculate sun event times once per day (expensive SunKit calculation)
    private static func calculateSunEventTimes(date: Date, timeZoneIdentifier: String) -> SunEventTimes {
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) else {
            // Fallback: use approximate times
            return SunEventTimes(
                sunriseHour: 6.0, sunsetHour: 18.0,
                civilDawnHour: 5.5, civilDuskHour: 18.5,
                nauticalDawnHour: 5.0, nauticalDuskHour: 19.0,
                astronomicalDawnHour: 4.5, astronomicalDuskHour: 19.5,
                solarNoonHour: 12.0
            )
        }
        
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        var sun = Sun(location: CLLocation(latitude: coords.latitude, longitude: coords.longitude), timeZone: timeZone)
        sun.setDate(date)
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        func hoursSinceMidnight(_ date: Date) -> Double {
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let second = calendar.component(.second, from: date)
            return Double(hour) + Double(minute) / 60.0 + Double(second) / 3600.0
        }
        
        return SunEventTimes(
            sunriseHour: hoursSinceMidnight(sun.sunrise),
            sunsetHour: hoursSinceMidnight(sun.sunset),
            civilDawnHour: hoursSinceMidnight(sun.civilDawn),
            civilDuskHour: hoursSinceMidnight(sun.civilDusk),
            nauticalDawnHour: hoursSinceMidnight(sun.nauticalDawn),
            nauticalDuskHour: hoursSinceMidnight(sun.nauticalDusk),
            astronomicalDawnHour: hoursSinceMidnight(sun.astronomicalDawn),
            astronomicalDuskHour: hoursSinceMidnight(sun.astronomicalDusk),
            solarNoonHour: hoursSinceMidnight(sun.solarNoon)
        )
    }
    
    // Fast calculation using cached sun times (no SunKit calls)
    private static func calculateNormalizedTimeFromSunTimes(date: Date, timeZoneIdentifier: String, sunTimes: SunEventTimes) -> Double {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        func hoursSinceMidnight(_ date: Date) -> Double {
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let second = calendar.component(.second, from: date)
            return Double(hour) + Double(minute) / 60.0 + Double(second) / 3600.0
        }
        
        let currentHour = hoursSinceMidnight(date)
        
        // Use cached sun times
        let sunriseHour = sunTimes.sunriseHour
        let sunsetHour = sunTimes.sunsetHour
        let civilDawnHour = sunTimes.civilDawnHour
        let civilDuskHour = sunTimes.civilDuskHour
        let nauticalDawnHour = sunTimes.nauticalDawnHour
        let nauticalDuskHour = sunTimes.nauticalDuskHour
        let astronomicalDawnHour = sunTimes.astronomicalDawnHour
        let astronomicalDuskHour = sunTimes.astronomicalDuskHour
        let solarNoonHour = sunTimes.solarNoonHour
        
        // Normalize times to handle day/night transitions across midnight
        // We'll map the actual sun events to a standard 24-hour pattern:
        // 0-4: Deep night
        // 4-5: Astronomical twilight (dawn)
        // 5-6: Nautical twilight (dawn)
        // 6-7: Civil twilight (dawn)
        // 7-8: Sunrise period
        // 8-11: Morning
        // 11-14: Noon period
        // 14-17: Afternoon
        // 17-18: Golden hour (before sunset)
        // 18-19: Sunset period
        // 19-20: Civil twilight (dusk)
        // 20-21: Nautical twilight (dusk)
        // 21-24: Astronomical twilight to night
        
        // Determine which phase of the day we're in
        // Note: Order of events (evening): sunset -> civilDusk -> nauticalDusk -> astronomicalDusk -> night
        // Order of events (morning): astronomicalDawn -> nauticalDawn -> civilDawn -> sunrise -> day
        
        if currentHour >= sunsetHour || currentHour < sunriseHour {
            // Night period: between sunset and sunrise
            if currentHour >= sunsetHour {
                // Evening/night after sunset
                if currentHour < sunsetHour + 1.0 {
                    // Sunset period (18-19 equivalent)
                    let progress = (currentHour - sunsetHour) / 1.0
                    return 18.0 + min(progress, 1.0)
                } else if currentHour < civilDuskHour {
                    // Civil twilight evening (19-20 equivalent)
                    let progress = (currentHour - (sunsetHour + 1.0)) / max(0.1, civilDuskHour - (sunsetHour + 1.0))
                    return 19.0 + min(progress, 1.0)
                } else if currentHour < nauticalDuskHour {
                    // Nautical twilight evening (20-21 equivalent)
                    let progress = (currentHour - civilDuskHour) / max(0.1, nauticalDuskHour - civilDuskHour)
                    return 20.0 + min(progress, 1.0)
                } else if currentHour < astronomicalDuskHour {
                    // Astronomical twilight evening (21-22 equivalent)
                    let progress = (currentHour - nauticalDuskHour) / max(0.1, astronomicalDuskHour - nauticalDuskHour)
                    return 21.0 + min(progress, 1.0)
                } else {
                    // Deep night after astronomical dusk (21-24 or 0-4 equivalent)
                    let hoursAfterDusk = currentHour - astronomicalDuskHour
                    let nightEnd = astronomicalDawnHour < sunriseHour ? astronomicalDawnHour + 24.0 : astronomicalDawnHour
                    let nightDuration = nightEnd - astronomicalDuskHour
                    if nightDuration > 0 {
                        let progress = hoursAfterDusk / nightDuration
                        if progress < 0.5 {
                            return 21.0 + progress * 6.0  // 21-24
                        } else {
                            return (progress - 0.5) * 8.0  // 0-4
                        }
                    }
                    return 22.0
                }
            } else {
                // Pre-dawn: before sunrise
                if currentHour >= astronomicalDawnHour {
                    // Astronomical twilight morning (4-5 equivalent)
                    let progress = (currentHour - astronomicalDawnHour) / max(0.1, nauticalDawnHour - astronomicalDawnHour)
                    return 4.0 + min(progress, 1.0)
                } else if currentHour >= nauticalDawnHour {
                    // Nautical twilight morning (5-6 equivalent)
                    let progress = (currentHour - nauticalDawnHour) / max(0.1, civilDawnHour - nauticalDawnHour)
                    return 5.0 + min(progress, 1.0)
                } else if currentHour >= civilDawnHour {
                    // Civil twilight morning (6-7 equivalent)
                    let progress = (currentHour - civilDawnHour) / max(0.1, sunriseHour - civilDawnHour)
                    return 6.0 + min(progress, 1.0)
                } else if currentHour >= sunriseHour - 1.0 {
                    // Just before sunrise (7 equivalent)
                    return 7.0
                } else {
                    // Deep night before dawn (0-4 equivalent)
                    let nightStart = astronomicalDuskHour
                    let hoursIntoNight = currentHour + (24.0 - nightStart)
                    let nightDuration = (astronomicalDawnHour + 24.0) - nightStart
                    if nightDuration > 0 {
                        let progress = hoursIntoNight / nightDuration
                        return progress * 4.0
                    }
                    return 2.0
                }
            }
        } else {
            // Day period: between astronomical dawn and astronomical dusk
            if currentHour < sunriseHour + 1.0 {
                // Sunrise period (7-8 equivalent)
                let progress = (currentHour - sunriseHour) / 1.0
                return 7.0 + min(progress, 1.0)
            } else if currentHour < sunriseHour + 4.0 {
                // Morning (8-11 equivalent)
                let progress = (currentHour - sunriseHour - 1.0) / 3.0
                return 8.0 + progress * 3.0
            } else if abs(currentHour - solarNoonHour) < 1.5 {
                // Noon period (11-14 equivalent)
                let progress = (currentHour - (solarNoonHour - 1.5)) / 3.0
                return 11.0 + min(max(progress, 0), 3.0)
            } else if currentHour < sunsetHour - 1.0 {
                // Afternoon (14-17 equivalent)
                let afternoonStart = solarNoonHour + 1.5
                let progress = (currentHour - afternoonStart) / max(0.1, (sunsetHour - 1.0) - afternoonStart)
                return 14.0 + min(progress, 1.0) * 3.0
            } else {
                // Golden hour before sunset (17-18 equivalent)
                let progress = (currentHour - (sunsetHour - 1.0)) / 1.0
                return 17.0 + min(progress, 1.0)
            }
        }
    }
    
    // Fallback time calculation (original implementation)
    private static func calculateFallbackTime(date: Date, timeZoneIdentifier: String) -> Double {
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        
        let hour = localCalendar.component(.hour, from: date)
        let minute = localCalendar.component(.minute, from: date)
        return Double(hour) + Double(minute) / 60.0
    }
    
    // Calculate time value for animation (using normalized time)
    private var timeValue: Double {
        return normalizedTime
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
            // Astronomical twilight (4:00 - 5:00) - Deep greyish-blue dawn
            let progress = (normalizedTime - 4)
            return [
                // Zenith: Dark charcoal blue transitioning to greyish-blue
                Color(red: 0.05 + 0.03 * progress, green: 0.05 + 0.03 * progress, blue: 0.12 + 0.18 * progress),
                // Upper sky: Slightly lighter slate blue
                Color(red: 0.05 + 0.04 * progress, green: 0.05 + 0.04 * progress, blue: 0.15 + 0.2 * progress),
                // Mid-sky: Greyish-blue with dawn hints
                Color(red: 0.06 + 0.05 * progress, green: 0.06 + 0.05 * progress, blue: 0.18 + 0.22 * progress),
                // Horizon: Blue-grey with first light undertones
                Color(red: 0.07 + 0.06 * progress, green: 0.07 + 0.06 * progress, blue: 0.2 + 0.2 * progress)
            ]
            
        case 5..<6:
            // Nautical twilight (5:00 - 6:00) - Greyish-blue dawn transition
            let progress = (normalizedTime - 5)
            return [
                // Zenith: Greyish-blue brightening towards civil twilight
                Color(red: 0.08 + 0.12 * progress, green: 0.08 + 0.07 * progress, blue: 0.3 + 0.15 * progress),
                // Upper sky: Slate blue with grey undertones
                Color(red: 0.09 + 0.11 * progress, green: 0.09 + 0.11 * progress, blue: 0.35 + 0.15 * progress),
                // Mid-sky: Blue-grey with dawn progression
                Color(red: 0.11 + 0.14 * progress, green: 0.11 + 0.09 * progress, blue: 0.4 + 0.1 * progress),
                // Horizon: Lighter blue-grey with first warm hints
                Color(red: 0.13 + 0.17 * progress, green: 0.13 + 0.07 * progress, blue: 0.4 + 0.1 * progress)
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
            // Greyish-blue atmosphere with balanced tones
            let progress = (normalizedTime - 19)
            return [
                // Zenith: Steel blue with grey undertones
                Color(red: 0.2 - 0.05 * progress, green: 0.25 - 0.07 * progress, blue: 0.5 - 0.1 * progress),
                // Upper sky: Lighter greyish-blue
                Color(red: 0.22 - 0.06 * progress, green: 0.28 - 0.09 * progress, blue: 0.48 - 0.1 * progress),
                // Mid sky: Blue-grey with twilight transition
                Color(red: 0.25 - 0.07 * progress, green: 0.3 - 0.1 * progress, blue: 0.45 - 0.1 * progress),
                // Horizon: Muted blue-grey with last light
                Color(red: 0.28 - 0.08 * progress, green: 0.3 - 0.09 * progress, blue: 0.4 - 0.08 * progress)
            ]
            
        case 20..<21:
            // Nautical twilight (20:00 - 21:00)
            // Sun is 6-12° below horizon - greyish-blue to dark slate transition
            let progress = (normalizedTime - 20)
            return [
                // Zenith: Dark greyish-blue transitioning to charcoal blue
                Color(red: 0.15 - 0.1 * progress, green: 0.18 - 0.13 * progress, blue: 0.4 - 0.25 * progress),
                // Upper sky: Deep slate blue with grey undertones
                Color(red: 0.16 - 0.11 * progress, green: 0.19 - 0.14 * progress, blue: 0.38 - 0.23 * progress),
                // Mid sky: Greyish-blue with faint twilight remnants
                Color(red: 0.18 - 0.13 * progress, green: 0.2 - 0.15 * progress, blue: 0.35 - 0.2 * progress),
                // Horizon: Last traces of twilight, blue-grey blend
                Color(red: 0.2 - 0.15 * progress, green: 0.21 - 0.16 * progress, blue: 0.32 - 0.17 * progress)
            ]
            
        default:
            // Astronomical twilight to Night (21:00 - 24:00)
            let progress = min((normalizedTime - 21) / 3, 1)
            return [
                // Deep greyish-blue to charcoal black
                Color(red: 0.05 - 0.03 * progress, green: 0.05 - 0.03 * progress, blue: 0.15 - 0.1 * progress),
                Color(red: 0.05 - 0.035 * progress, green: 0.05 - 0.035 * progress, blue: 0.15 - 0.11 * progress),
                Color(red: 0.05 - 0.04 * progress, green: 0.05 - 0.04 * progress, blue: 0.12 - 0.09 * progress)
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
