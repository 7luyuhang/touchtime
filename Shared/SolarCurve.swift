//
//  SolarCurve.swift
//  touchtime
//
//  Created on 14/01/2026.
//

import SwiftUI

struct SolarCurve: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    let showBackground: Bool
    
    // Cache the Path to avoid recreating it on every body update
    @State private var cachedPath: Path?
    @State private var cachedDayKey: String = ""
    
    // Cache daily sun times per timezone to avoid repeated calculations
    private struct SunTimes {
        let sunrise: Date?
        let sunset: Date?
        let solarNoon: Date?
    }
    
    // Cache curve points for a day (curve doesn't change during the day).
    // Points are normalized to a unit square (0...1) so every view size can
    // share the same per-day cache entry.
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
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false, showBackground: Bool = true) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        self.showBackground = showBackground
    }
    
    // Generate day key for caching (only changes when date changes, not time)
    private func dayKey(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)"
    }
    
    // Create Path from normalized curve data using a Catmull-Rom spline converted to
    // cubic Béziers. Scaling from unit space to the current size happens here, so the
    // cached points stay size-independent. The curve passes through every sample point
    // with continuous tangents, avoiding visible kinks at the hourly sample points.
    private func createPath(from curveData: CurveData) -> Path {
        var path = Path()
        let points = curveData.curvePoints.map { CGPoint(x: $0.x * size, y: $0.y * size) }
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 0..<(points.count - 1) {
            // Neighbouring points, clamped at the ends
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            
            // Catmull-Rom to cubic Bézier conversion (tension = 0)
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        
        return path
    }
    
    // Get cached sun times for this day/timezone
    private func cachedSunTimes(for date: Date) -> SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_solarcurve_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = SolarCurve.sunTimesCache.object(forKey: cacheKey) {
            return cached.times
        }
        
        let times: SunTimes
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let events = SolarCalculator.events(latitude: coords.latitude, longitude: coords.longitude, date: date, timeZone: timeZone)
            times = SunTimes(sunrise: events.sunrise, sunset: events.sunset, solarNoon: events.solarNoon)
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
        SolarCurve.sunTimesCache.setObject(SunTimesWrapper(times), forKey: cacheKey)
        
        return times
    }
    
    // Get cached curve data for the day (curve doesn't change during the day)
    private func cachedCurveData(for date: Date) -> CurveData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_curve_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache
        if let cached = SolarCurve.curveDataCache.object(forKey: cacheKey) {
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
        
        // Generate curve points - use 24 points (one per hour) for smooth curve.
        // Points are in unit space (0...1); createPath(from:) scales them to size.
        var curvePoints: [CGPoint] = []
        let horizonY = 0.5 // Horizon line at center
        let amplitude = 0.35 // Maximum height of the curve above/below horizon
        
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
                curvePoints.append(CGPoint(x: hours / 24.0, y: yPosition))
            }
            
            let data = CurveData(curvePoints: curvePoints, daylightRatio: daylightRatio)
            SolarCurve.curveDataCache.setObject(CurveDataWrapper(data), forKey: cacheKey)
            return data
        }
        
        // Calculate points every hour (24 points total) - cached per day
        for hour in 0...24 {
            let hours = Double(hour)
            let hourDate = startOfDay.addingTimeInterval(hours * 3600)
            let sunAltitude = SolarCalculator.position(latitude: coords.latitude, longitude: coords.longitude, date: hourDate).altitude
            
            // Normalize altitude to -90 to 90 degrees, then map to y position
            let normalizedAltitude = max(-90, min(90, sunAltitude))
            let yPosition = horizonY - (normalizedAltitude / 90.0) * amplitude
            curvePoints.append(CGPoint(x: hours / 24.0, y: yPosition))
        }
        
        let data = CurveData(curvePoints: curvePoints, daylightRatio: daylightRatio)
        SolarCurve.curveDataCache.setObject(CurveDataWrapper(data), forKey: cacheKey)
        
        return data
    }
    
    var body: some View {
        // Use cached path if available, otherwise create empty path (will be set in onAppear/onChange)
        let curvePath = cachedPath ?? Path()
        
        ZStack {
            // Background circle
            if showBackground {
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
            }
            
            // Curve above horizon (opacity 1.0)
            curvePath
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
        .onChange(of: date) { oldDate, newDate in
            // Only update path when day actually changes (not just time)
            let oldDayKey = dayKey(for: oldDate)
            let newDayKey = dayKey(for: newDate)
            if oldDayKey != newDayKey {
                let curveData = cachedCurveData(for: newDate)
                cachedPath = createPath(from: curveData)
                cachedDayKey = newDayKey
            }
        }
        .onAppear {
            // Initialize cached path on first appearance
            let currentDayKey = dayKey(for: date)
            if cachedPath == nil || cachedDayKey != currentDayKey {
                let curveData = cachedCurveData(for: date)
                cachedPath = createPath(from: curveData)
                cachedDayKey = currentDayKey
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        SolarCurve(
            date: Date(),
            timeZone: .current,
            size: 100
        )
    }
}
