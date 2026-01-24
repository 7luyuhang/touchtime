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
    
    // Wrapper class for NSCache (NSCache requires reference types)
    private class SunEventTimesWrapper {
        let times: SunEventTimes
        init(_ times: SunEventTimes) { self.times = times }
    }
    
    // Thread-safe, lock-free cache using NSCache
    private static let sunTimesCache: NSCache<NSString, SunEventTimesWrapper> = {
        let cache = NSCache<NSString, SunEventTimesWrapper>()
        cache.countLimit = 30 // Keep last 30 entries
        return cache
    }()
    
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
        let cacheKey = "\(timeZoneIdentifier)_\(dayComponents.year ?? 0)_\(dayComponents.month ?? 0)_\(dayComponents.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        let sunTimes: SunEventTimes
        if let cached = sunTimesCache.object(forKey: cacheKey) {
            sunTimes = cached.times
        } else {
            // Calculate sun event times once per day
            let times = calculateSunEventTimes(date: date, timeZoneIdentifier: timeZoneIdentifier)
            sunTimesCache.setObject(SunEventTimesWrapper(times), forKey: cacheKey)
            sunTimes = times
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
                // Check from latest event to earliest: civilDawn -> nauticalDawn -> astronomicalDawn
                // Order of events: astronomicalDawnHour < nauticalDawnHour < civilDawnHour < sunriseHour
                if currentHour >= civilDawnHour {
                    // Civil twilight morning (6-7 equivalent) - closest to sunrise
                    let progress = (currentHour - civilDawnHour) / max(0.1, sunriseHour - civilDawnHour)
                    return 6.0 + min(progress, 1.0)
                } else if currentHour >= nauticalDawnHour {
                    // Nautical twilight morning (5-6 equivalent)
                    let progress = (currentHour - nauticalDawnHour) / max(0.1, civilDawnHour - nauticalDawnHour)
                    return 5.0 + min(progress, 1.0)
                } else if currentHour >= astronomicalDawnHour {
                    // Astronomical twilight morning (4-5 equivalent) - earliest dawn
                    let progress = (currentHour - astronomicalDawnHour) / max(0.1, nauticalDawnHour - astronomicalDawnHour)
                    return 4.0 + min(progress, 1.0)
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
                Color(red: 0.005, green: 0.008, blue: 0.02), // Deep Space
                Color(red: 0.01, green: 0.015, blue: 0.04),  // Upper Atmosphere
                Color(red: 0.015, green: 0.022, blue: 0.05 + 0.01 * (1 - progress)), // Lower Atmosphere (Interpolated)
                Color(red: 0.02, green: 0.03, blue: 0.06 + 0.02 * (1 - progress)) // Horizon
            ]
            
        case 4..<5:
            // Astronomical Twilight (4:00 - 5:00)
            // First hint of scattering, deep indigo/violet
            let progress = (normalizedTime - 4)
            return [
                Color(red: 0.01, green: 0.01, blue: 0.05),   // Zenith
                Color(red: 0.02, green: 0.025, blue: 0.10 + 0.05 * progress), // Mid
                Color(red: 0.025, green: 0.032, blue: 0.125 + 0.075 * progress), // Lower (Interpolated)
                Color(red: 0.03, green: 0.04, blue: 0.15 + 0.10 * progress)   // Horizon (Indigo)
            ]
            
        case 5..<6:
            // Nautical Twilight (5:00 - 6:00)
            // "Blue Hour" begins. Ozone absorption (Chappuis band) contributes to rich blues.
            let progress = (normalizedTime - 5)
            return [
                Color(red: 0.02, green: 0.03, blue: 0.12 + 0.05 * progress), // Zenith
                Color(red: 0.05, green: 0.08, blue: 0.25 + 0.1 * progress),  // Upper
                Color(red: 0.10 + 0.05 * progress, green: 0.15 + 0.05 * progress, blue: 0.40 + 0.1 * progress), // Mid
                Color(red: 0.15 + 0.1 * progress, green: 0.20 + 0.1 * progress, blue: 0.45 + 0.05 * progress)   // Horizon
            ]
            
        case 6..<7:
            // Civil Twilight / Dawn (6:00 - 7:00)
            // Scattering intensifies. Horizon transitions from blue to cool pink/lavender (Less yellow).
            let progress = (normalizedTime - 6)
            return [
                Color(red: 0.05, green: 0.1, blue: 0.35), // Zenith (Deep Blue)
                Color(red: 0.2, green: 0.25, blue: 0.55), // Mid Sky
                Color(red: 0.5 + 0.1 * progress, green: 0.35 + 0.05 * progress, blue: 0.55), // Transition (Lavender)
                Color(red: 0.75 + 0.1 * progress, green: 0.5 + 0.1 * progress, blue: 0.5 + 0.1 * progress) // Horizon (Cool Pink -> Pale Peach)
            ]
            
        case 7..<8:
            // Sunrise (7:00 - 8:00)
            // Sun breaches horizon. Intense brightness with clean white/blue tones (Less intense yellow).
            let progress = (normalizedTime - 7)
            return [
                Color(red: 0.15, green: 0.4 + 0.1 * progress, blue: 0.7 + 0.05 * progress), // Zenith (Clean Blue)
                Color(red: 0.45 + 0.1 * progress, green: 0.6 + 0.1 * progress, blue: 0.85), // Upper (Sky Blue)
                Color(red: 0.75 + 0.1 * progress, green: 0.75 + 0.1 * progress, blue: 0.9), // Mid (Pale Blue/White)
                Color(red: 0.95, green: 0.85 - 0.05 * progress, blue: 0.7 + 0.2 * progress) // Horizon (Bright White-Gold)
            ]
            
        case 8..<11:
            // Morning (8:00 - 11:00)
            // Atmosphere clears. Rayleigh scattering stabilizes to pure blue.
            let progress = (normalizedTime - 8) / 3
            return [
                Color(red: 0.1 + 0.05 * progress, green: 0.4 + 0.1 * progress, blue: 0.75 + 0.05 * progress), // Zenith (Deep Blue)
                Color(red: 0.25 + 0.05 * progress, green: 0.55 + 0.05 * progress, blue: 0.85), // Mid
                Color(red: 0.5 + 0.1 * progress, green: 0.7 + 0.05 * progress, blue: 0.9), // Lower
                Color(red: 0.7 + 0.1 * progress, green: 0.85 + 0.05 * progress, blue: 0.95) // Horizon (Pale due to Mie scattering)
            ]
            
        case 11..<14:
            // Noon (11:00 - 14:00)
            // Maximum brightness. Shortest optical path.
            return [
                Color(red: 0.15, green: 0.48, blue: 0.85), // Zenith (Rich Nitrogen Blue)
                Color(red: 0.30, green: 0.60, blue: 0.90), // Mid
                Color(red: 0.60, green: 0.80, blue: 0.95), // Lower
                Color(red: 0.85, green: 0.92, blue: 0.98)  // Horizon (Haze/White)
            ]
            
        case 14..<17:
            // Afternoon (14:00 - 17:00)
            // Light warms slightly as path length increases.
            let progress = (normalizedTime - 14) / 3
            return [
                Color(red: 0.15, green: 0.48 - 0.05 * progress, blue: 0.85 - 0.1 * progress), // Zenith
                Color(red: 0.30 + 0.05 * progress, green: 0.60 - 0.05 * progress, blue: 0.90 - 0.05 * progress), // Mid
                Color(red: 0.60 + 0.1 * progress, green: 0.80 - 0.05 * progress, blue: 0.95 - 0.05 * progress), // Lower
                Color(red: 0.85 + 0.05 * progress, green: 0.92 - 0.05 * progress, blue: 0.98 - 0.05 * progress)  // Horizon
            ]
            
        case 17..<18:
            // Golden Hour (17:00 - 18:00)
            // Blue scatters out, leaving warm golden tones. (Desaturated for realism)
            let progress = (normalizedTime - 17)
            return [
                Color(red: 0.2 + 0.05 * progress, green: 0.45 - 0.05 * progress, blue: 0.7 - 0.1 * progress), // Zenith (Softer Blue)
                Color(red: 0.45 + 0.1 * progress, green: 0.58 - 0.03 * progress, blue: 0.75 - 0.1 * progress), // Mid
                Color(red: 0.7 + 0.1 * progress, green: 0.75 - 0.15 * progress, blue: 0.85 - 0.25 * progress), // Lower
                Color(red: 0.9 + 0.05 * progress, green: 0.85 - 0.15 * progress, blue: 0.8 - 0.3 * progress) // Horizon (Soft Gold/White)
            ]
            
        case 18..<19:
            // Sunset (18:00 - 19:00)
            // Dramatic spectrum split. Deep blue above, soft red/orange below (Natural saturation)
            let progress = (normalizedTime - 18)
            return [
                Color(red: 0.15 + 0.05 * progress, green: 0.3 - 0.1 * progress, blue: 0.5 - 0.1 * progress), // Zenith
                Color(red: 0.4 + 0.1 * progress, green: 0.4 - 0.05 * progress, blue: 0.55 - 0.15 * progress), // Upper
                Color(red: 0.75 + 0.1 * progress, green: 0.55 - 0.15 * progress, blue: 0.5 - 0.15 * progress), // Mid (Soft Salmon)
                Color(red: 0.95 - 0.1 * progress, green: 0.7 - 0.35 * progress, blue: 0.5 - 0.25 * progress) // Horizon (Soft Orange -> Burnt Orange)
            ]
            
        case 19..<20:
            // Civil Dusk (19:00 - 20:00)
            // The "Belt of Venus" effect fading into blue hour.
            let progress = (normalizedTime - 19)
            return [
                Color(red: 0.05 + 0.05 * progress, green: 0.1 - 0.05 * progress, blue: 0.4 - 0.1 * progress), // Zenith
                Color(red: 0.2, green: 0.25 - 0.1 * progress, blue: 0.5 - 0.1 * progress), // Upper
                Color(red: 0.5 - 0.2 * progress, green: 0.35 - 0.2 * progress, blue: 0.45 - 0.1 * progress), // Mid (Purple/Fade)
                Color(red: 0.8 - 0.4 * progress, green: 0.4 - 0.2 * progress, blue: 0.3 - 0.1 * progress) // Horizon (Fading Sunset)
            ]
            
        case 20..<21:
            // Nautical Dusk (20:00 - 21:00)
            // Horizon glow remains, but colors desaturate rapidly.
            let progress = (normalizedTime - 20)
            return [
                Color(red: 0.02, green: 0.03, blue: 0.15 - 0.05 * progress), // Zenith
                Color(red: 0.08, green: 0.1, blue: 0.25 - 0.05 * progress), // Upper
                Color(red: 0.15 - 0.05 * progress, green: 0.15 - 0.05 * progress, blue: 0.3 - 0.1 * progress), // Mid
                Color(red: 0.25 - 0.15 * progress, green: 0.2 - 0.1 * progress, blue: 0.3 - 0.1 * progress) // Horizon
            ]
            
        default:
            // Astronomical Dusk to Night (21:00 - 24:00)
            // Returning to deep space black/navy.
            let progress = min((normalizedTime - 21) / 3, 1)
            return [
                Color(red: 0.01, green: 0.01, blue: 0.05 - 0.03 * progress), // Zenith
                Color(red: 0.02, green: 0.02, blue: 0.08 - 0.04 * progress), // Mid
                Color(red: 0.03 - 0.01 * progress, green: 0.035 - 0.01 * progress, blue: 0.10 - 0.05 * progress), // Lower (Interpolated)
                Color(red: 0.04 - 0.02 * progress, green: 0.05 - 0.02 * progress, blue: 0.12 - 0.06 * progress) // Horizon
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
    
    // Get the animation value for smooth transitions (hourly granularity to reduce animation overhead)
    var animationValue: Int {
        return Int(timeValue)
    }
}
