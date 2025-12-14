//
//  SunPositionIndicator.swift
//  touchtime
//
//  Created on 13/12/2025.
//

import SwiftUI
import SunKit
import CoreLocation

struct SunPositionIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    
    // Cache daily sun times per timezone to avoid repeated SunKit calculations
    private struct SunTimes {
        let sunrise: Date?
        let sunset: Date?
        let solarNoon: Date?
    }
    
    private static var sunTimesCache: [String: SunTimes] = [:]
    private static let cacheQueue = DispatchQueue(label: "SunPositionIndicator.cache")
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }
    
    // Calculate sun position using real sunrise/sunset/solar noon for the city
    private var sunPosition: SunPositionInfo {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let startOfDay = calendar.startOfDay(for: date)
        let dayInSeconds: Double = 24 * 60 * 60
        
        // Fetch cached sun times for this day/timezone (uses SunKit when available)
        let sunTimes = cachedSunTimes(for: date)
        
        // Fallback to a simple approximation if we cannot get solar noon
        guard let solarNoon = sunTimes.solarNoon else {
            let secondsFromNoon = date.timeIntervalSince(startOfDay.addingTimeInterval(12 * 3600))
            let progress = secondsFromNoon / dayInSeconds
            let verticalPosition = CGFloat(cos(2 * .pi * progress))
            return SunPositionInfo(verticalPosition: verticalPosition, progress: progress + 0.5)
        }
        
        let sunrise = sunTimes.sunrise
        let sunset = sunTimes.sunset
        
        // Use real daylight duration; fall back to 12h to avoid division by zero
        let daylightDuration: TimeInterval
        if let sunrise = sunrise, let sunset = sunset, sunset > sunrise {
            daylightDuration = max(60, sunset.timeIntervalSince(sunrise))
        } else {
            daylightDuration = 12 * 3600
        }
        let halfDayDuration = daylightDuration / 2.0
        
        // Let the sun cross the horizon (0) exactly at sunrise/sunset, peak at solar noon
        let secondsFromNoon = date.timeIntervalSince(solarNoon)
        let angle = (secondsFromNoon / halfDayDuration) * (Double.pi / 2)
        // Clamp extreme nights to avoid oscillation when far from the day window
        let clampedAngle = max(-Double.pi, min(Double.pi, angle))
        let verticalPosition = CGFloat(cos(clampedAngle))
        
        // Progress through the daylight window (0 = sunrise, 1 = sunset), fallback to 24h
        let progress: Double
        if let sunrise = sunrise, let sunset = sunset, sunset > sunrise {
            progress = max(0, min(1, date.timeIntervalSince(sunrise) / (sunset.timeIntervalSince(sunrise))))
        } else {
            progress = max(0, min(1, date.timeIntervalSince(startOfDay) / dayInSeconds))
        }
        
        return SunPositionInfo(verticalPosition: verticalPosition, progress: progress)
    }
    
    // Get (or compute) sun times for the given day and timezone with caching
    private func cachedSunTimes(for date: Date) -> SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)"
        
        // Return cached value if present
        if let cached = SunPositionIndicator.cacheQueue.sync(execute: { SunPositionIndicator.sunTimesCache[cacheKey] }) {
            return cached
        }
        
        let times: SunTimes
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)
            sun.setDate(date)
            times = SunTimes(sunrise: sun.sunrise, sunset: sun.sunset, solarNoon: sun.solarNoon)
        } else {
            // Fallback approximation when coordinates are unavailable
            times = SunTimes(
                sunrise: calendar.date(byAdding: .hour, value: 6, to: calendar.startOfDay(for: date)),
                sunset: calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: date)),
                solarNoon: calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))
            )
        }
        
        // Store in cache with a small cap
        SunPositionIndicator.cacheQueue.sync {
            SunPositionIndicator.sunTimesCache[cacheKey] = times
            if SunPositionIndicator.sunTimesCache.count > 60 {
                let keysToRemove = Array(SunPositionIndicator.sunTimesCache.keys.prefix(SunPositionIndicator.sunTimesCache.count - 60))
                for key in keysToRemove {
                    SunPositionIndicator.sunTimesCache.removeValue(forKey: key)
                }
            }
        }
        
        return times
    }
    
    var body: some View {
        let position = sunPosition
        let sunRadius: CGFloat = size * 0.08
        let trackHeight = size * 0.75
        let sunYOffset = position.verticalPosition * (trackHeight / 2 - sunRadius)
        let sunSize = sunRadius * 2.5
        let sunCenterOffset = -sunYOffset
        
        ZStack {
            if useMaterialBackground {
                Circle()
                    .fill(.black.opacity(0.05))
                    .blendMode(.plusDarker)
            } else {
                Circle()
                    .fill(.clear)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.10))
                            .glassEffect(.clear)
                    )
            }
            
            // Horizontal Line
            Capsule()
                .fill(.white.opacity(0.10))
                .frame(width: size, height: 1)
                .blendMode(.plusLighter)
            
            // Sun Indicator
            ZStack {
                // Filled portion
                Circle()
                    .fill(.white)
                    .frame(width: sunSize + 1.5, height: sunSize + 1.5)
                    .offset(y: sunCenterOffset)
                    .mask {
                        // Keep the fill only in the upper half of the indicator frame
                        Rectangle()
                            .frame(width: size * 2, height: size / 2)
                            .offset(y: -size / 4)
                    }
                    .blendMode(.plusLighter)
                
                // Stroke portion
                Circle()
                    .stroke(lineWidth: 1.5)
                    .frame(width: sunSize, height: sunSize)
                    .offset(y: sunCenterOffset)
                    .mask {
                        Rectangle()
                            .frame(width: size * 2, height: size / 2)
                            .offset(y: size / 4)
                    }
                    .opacity(0.5)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: size, height: size)
    }
}

// Helper struct to hold sun position information
private struct SunPositionInfo: Equatable {
    let verticalPosition: CGFloat
    let progress: Double
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        HStack(spacing: 40) {
            SunPositionIndicator(
                date: Date(),
                timeZone: .current,
                size: 100
            )
            
            AnalogClockView(
                date: Date(),
                size: 100,
                timeZone: .current
            )
        }
    }
}

