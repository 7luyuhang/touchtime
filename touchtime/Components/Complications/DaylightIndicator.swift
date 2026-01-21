//
//  DaylightIndicator.swift
//  touchtime
//
//  Created on 14/01/2026.
//

import SwiftUI
import SunKit
import CoreLocation

struct DaylightIndicator: View {
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
    
    // Cache curve points for a day (curve doesn't change during the day)
    private struct CurveData {
        let curvePoints: [CGPoint]
        let daylightRatio: Double
    }
    
    // Wrapper classes for NSCache (NSCache requires reference types)
    private class SunTimesWrapper {
        let times: SunTimes
        init(_ times: SunTimes) { self.times = times }
    }
    
    private class CurveDataWrapper {
        let data: CurveData
        init(_ data: CurveData) { self.data = data }
    }
    
    // Thread-safe, lock-free cache using NSCache
    private static let sunTimesCache: NSCache<NSString, SunTimesWrapper> = {
        let cache = NSCache<NSString, SunTimesWrapper>()
        cache.countLimit = 60 // Keep last 60 entries
        return cache
    }()
    
    // Cache for curve points (per day)
    private static let curveDataCache: NSCache<NSString, CurveDataWrapper> = {
        let cache = NSCache<NSString, CurveDataWrapper>()
        cache.countLimit = 60 // Keep last 60 entries
        return cache
    }()
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }
    
    // Get cached sun times for this day/timezone
    private func cachedSunTimes(for date: Date) -> SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_daylight_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = DaylightIndicator.sunTimesCache.object(forKey: cacheKey) {
            return cached.times
        }
        
        let times: SunTimes
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)
            sun.setDate(date)
            times = SunTimes(sunrise: sun.sunrise, sunset: sun.sunset, solarNoon: sun.solarNoon)
        } else {
            // Fallback approximation when coordinates are unavailable
            let startOfDay = calendar.startOfDay(for: date)
            times = SunTimes(
                sunrise: calendar.date(byAdding: .hour, value: 6, to: startOfDay),
                sunset: calendar.date(byAdding: .hour, value: 18, to: startOfDay),
                solarNoon: calendar.date(byAdding: .hour, value: 12, to: startOfDay)
            )
        }
        
        // Store in cache
        DaylightIndicator.sunTimesCache.setObject(SunTimesWrapper(times), forKey: cacheKey)
        
        return times
    }
    
    // Get cached curve data for the day (curve doesn't change during the day)
    private func cachedCurveData(for date: Date) -> CurveData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_curve_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache
        if let cached = DaylightIndicator.curveDataCache.object(forKey: cacheKey) {
            return cached.data
        }
        
        let sunTimes = cachedSunTimes(for: date)
        let startOfDay = calendar.startOfDay(for: date)
        let dayInSeconds: Double = 24 * 60 * 60
        
        // Calculate daylight duration
        let daylightDuration: TimeInterval
        if let sunrise = sunTimes.sunrise, let sunset = sunTimes.sunset, sunset > sunrise {
            daylightDuration = sunset.timeIntervalSince(sunrise)
        } else {
            daylightDuration = 12 * 3600 // Fallback to 12 hours
        }
        
        let daylightRatio = daylightDuration / dayInSeconds
        
        // Generate curve points - use 24 points (one per hour) for smooth curve
        var curvePoints: [CGPoint] = []
        let width = size
        let height = size
        let horizonY = height / 2 // Horizon line at center
        let amplitude = height * 0.35 // Maximum height of the curve above/below horizon
        
        // Calculate points every hour (24 points total: 0, 1, 2, ..., 24) - cached per day
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            // Fallback: use simple cosine approximation
            for hour in 0...24 {
                let hours = Double(hour)
                let secondsFromNoon = (hours - 12) * 3600
                let progress = secondsFromNoon / dayInSeconds
                let sunAltitude = 90 * cos(2 * .pi * progress)
                let normalizedAltitude = max(-90, min(90, sunAltitude))
                let yPosition = horizonY - (normalizedAltitude / 90.0) * amplitude
                // Ensure positions stay within bounds
                let xPosition = max(0, min(width, (hours / 24.0) * width))
                let clampedYPosition = max(0, min(height, yPosition))
                curvePoints.append(CGPoint(x: xPosition, y: clampedYPosition))
            }
            
            let data = CurveData(curvePoints: curvePoints, daylightRatio: daylightRatio)
            DaylightIndicator.curveDataCache.setObject(CurveDataWrapper(data), forKey: cacheKey)
            return data
        }
        
        // Use SunKit for accurate calculations - but cache the results
        let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
        var sun = Sun(location: location, timeZone: timeZone)
        
        // Calculate points every hour (24 points total)
        for hour in 0...24 {
            let hours = Double(hour)
            let hourDate = startOfDay.addingTimeInterval(hours * 3600)
            sun.setDate(hourDate)
            let sunAltitude = sun.altitude.degrees
            
            // Normalize altitude to -90 to 90 degrees, then map to y position
            let normalizedAltitude = max(-90, min(90, sunAltitude))
            let yPosition = horizonY - (normalizedAltitude / 90.0) * amplitude
            
            // Ensure x position stays within bounds (0 to width)
            let xPosition = max(0, min(width, (hours / 24.0) * width))
            // Ensure y position stays within bounds (0 to height)
            let clampedYPosition = max(0, min(height, yPosition))
            curvePoints.append(CGPoint(x: xPosition, y: clampedYPosition))
        }
        
        let data = CurveData(curvePoints: curvePoints, daylightRatio: daylightRatio)
        DaylightIndicator.curveDataCache.setObject(CurveDataWrapper(data), forKey: cacheKey)
        
        return data
    }
    
    var body: some View {
        // Cache curve data (only recalculated when day changes)
        let curveData = cachedCurveData(for: date)
        
        ZStack {
            // Background circle
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
            
            // Cosine curve path - use simpler quadratic curves for better performance
            let curvePath = Path { path in
                guard !curveData.curvePoints.isEmpty else { return }
                
                path.move(to: curveData.curvePoints[0])
                
                // Use simpler quadratic curves instead of Catmull-Rom for better performance
                for i in 1..<curveData.curvePoints.count {
                    let previousPoint = curveData.curvePoints[i - 1]
                    let currentPoint = curveData.curvePoints[i]
                    
                    // Control point for smooth quadratic curve
                    let controlPoint = CGPoint(
                        x: (previousPoint.x + currentPoint.x) / 2,
                        y: (previousPoint.y + currentPoint.y) / 2
                    )
                    
                    path.addQuadCurve(to: currentPoint, control: controlPoint)
                }
            }
            
            // Curve above horizon (opacity 1.0)
            curvePath
//                .fill(
//                    Color.white.opacity(0.15)
//                )
                .stroke(Color.white.opacity(1.0), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .blendMode(.plusLighter)
                .mask {
                    Rectangle()
                        .frame(width: size * 2, height: size / 2)
                        .offset(y: -size / 4)
                }
            
            // Curve below horizon (opacity 0.3)
            curvePath
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .blendMode(.plusLighter)
                .mask {
                    Rectangle()
                        .frame(width: size * 2, height: size / 2)
                        .offset(y: size / 4)
                }
                .drawingGroup() // Optimize rendering with Metal
            
            // Horizon line (horizontal line at center)
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: size, height: 1)
                .offset(y: 0)
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(Circle()) // Ensure all content is clipped to circle boundary
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        DaylightIndicator(
            date: Date(),
            timeZone: .current,
            size: 100
        )
    }
}
