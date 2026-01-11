//
//  SunriseSunsetIndicator.swift
//  touchtime
//
//  Created on 11/01/2026.
//

import SwiftUI
import SunKit
import CoreLocation

struct SunriseSunsetIndicator: View {
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
    
    // Wrapper class for NSCache (NSCache requires reference types)
    private class SunTimesWrapper {
        let times: SunTimes
        init(_ times: SunTimes) { self.times = times }
    }
    
    // Thread-safe, lock-free cache using NSCache
    private static let sunTimesCache: NSCache<NSString, SunTimesWrapper> = {
        let cache = NSCache<NSString, SunTimesWrapper>()
        cache.countLimit = 60
        return cache
    }()
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }
    
    // Get cached sun times for this day/timezone
    private var sunTimes: SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = Self.sunTimesCache.object(forKey: cacheKey) {
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
        Self.sunTimesCache.setObject(SunTimesWrapper(times), forKey: cacheKey)
        
        return times
    }
    
    // Calculate angle for a date (24-hour clock: 0h at top, clockwise)
    private func angleForDate(_ date: Date?) -> Double? {
        guard let date = date else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        // 24-hour clock: full rotation = 24 hours, 15 degrees per hour
        let hourAngle = Double(hour) * 15.0
        let minuteAngle = Double(minute) * 0.25 // 15/60 degrees per minute
        return hourAngle + minuteAngle
    }
    
    // Current time angle
    private var currentTimeAngle: Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        return hour * 15.0 + minute * 0.25
    }
    
    
    var body: some View {
        // Cache sunTimes once per body evaluation to avoid repeated lookups
        let times = sunTimes
        let sunriseAngle = angleForDate(times.sunrise)
        let sunsetAngle = angleForDate(times.sunset)
        let radius = size / 2
        let sunRadius: CGFloat = size * 0.15
        let orbitRadius: CGFloat = size * 0.35
        
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
            
            // Daylight arc fill between sunrise and sunset
            // Use drawingGroup() to flatten Path + Gradient into a single Metal texture for better performance
            if let sunriseAngle = sunriseAngle, let sunsetAngle = sunsetAngle {
                DaylightArc(
                    sunriseAngle: sunriseAngle,
                    sunsetAngle: sunsetAngle,
                    radius: radius
                )
                .drawingGroup()
                .blendMode(.plusLighter)
                
                // Sunrise and sunset lines
                SunTimeLinesView(
                    sunriseAngle: sunriseAngle,
                    sunsetAngle: sunsetAngle,
                    radius: radius,
                    lineWidth: 1.5
                )
                .drawingGroup()
                .blendMode(.plusLighter)
            }
            
            // Sun indicator with mask-based fill/stroke transition along sunrise/sunset lines
            if let sunriseAngle = sunriseAngle, let sunsetAngle = sunsetAngle {
                ZStack {
                    // Filled portion (daylight side) - masked by daylight arc
                    Circle()
                        .fill(.white)
                        .frame(width: sunRadius + 1.5, height: sunRadius + 1.5)
                        .offset(y: -orbitRadius)
                        .rotationEffect(.degrees(currentTimeAngle))
                        .mask {
                            SunArcMask(
                                startAngle: sunriseAngle,
                                endAngle: sunsetAngle,
                                size: size
                            )
                        }
                        .blendMode(.plusLighter)
                    
                    // Stroke portion (night side) - masked by night arc
                    Circle()
                        .stroke(lineWidth: 1.5)
                        .frame(width: sunRadius, height: sunRadius)
                        .offset(y: -orbitRadius)
                        .rotationEffect(.degrees(currentTimeAngle))
                        .mask {
                            SunArcMask(
                                startAngle: sunsetAngle,
                                endAngle: sunriseAngle,
                                size: size
                            )
                        }
                        .opacity(0.5)
                        .blendMode(.plusLighter)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Daylight Arc
private struct DaylightArc: View {
    let sunriseAngle: Double
    let sunsetAngle: Double
    let radius: CGFloat
    
    var body: some View {
        // Convert to radians (subtract 90 to align with clock where 0 is at top)
        let startRadians = (sunriseAngle - 90) * .pi / 180
        let endRadians = (sunsetAngle - 90) * .pi / 180
        
        Path { path in
            path.move(to: CGPoint(x: radius, y: radius))
            path.addArc(
                center: CGPoint(x: radius, y: radius),
                radius: radius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(
            RadialGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
        )
        .frame(width: radius * 2, height: radius * 2)
    }
}

// MARK: - Sun Arc Mask (pie-shaped mask for fill/stroke transition)
private struct SunArcMask: View {
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat
    
    var body: some View {
        let center = size / 2
        let startRadians = (startAngle - 90) * .pi / 180
        let endRadians = (endAngle - 90) * .pi / 180
        
        Path { path in
            path.move(to: CGPoint(x: center, y: center))
            path.addArc(
                center: CGPoint(x: center, y: center),
                radius: size,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(.white)
        .frame(width: size, height: size)
    }
}

// MARK: - Sun Time Lines View (combined)
private struct SunTimeLinesView: View {
    let sunriseAngle: Double
    let sunsetAngle: Double
    let radius: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        let sunriseRadians = (sunriseAngle - 90) * .pi / 180
        let sunsetRadians = (sunsetAngle - 90) * .pi / 180
        
        let center = CGPoint(x: radius, y: radius)
        let sunriseEnd = CGPoint(
            x: radius + radius * cos(sunriseRadians),
            y: radius + radius * sin(sunriseRadians)
        )
        let sunsetEnd = CGPoint(
            x: radius + radius * cos(sunsetRadians),
            y: radius + radius * sin(sunsetRadians)
        )
        
        // Combined path with both lines
        Path { path in
            path.move(to: center)
            path.addLine(to: sunriseEnd)
            path.move(to: center)
            path.addLine(to: sunsetEnd)
        }
        .stroke(
            Color.white.opacity(0.15),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .frame(width: radius * 2, height: radius * 2)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            HStack(spacing: 40) {
                SunriseSunsetIndicator(
                    date: Date(),
                    timeZone: .current,
                    size: 100
                )
                
                SunriseSunsetIndicator(
                    date: Date(),
                    timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current,
                    size: 100
                )
            }
        }
    }
}

