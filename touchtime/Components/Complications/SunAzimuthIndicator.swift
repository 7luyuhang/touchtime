//
//  SunAzimuthIndicator.swift
//  touchtime
//
//  Created on 14/12/2025.
//

import SwiftUI
import SunKit
import CoreLocation

struct SunAzimuthIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    
    // Cache hourly sun positions for a given day/timezone, then interpolate for smooth animation
    private struct HourlySunData {
        let azimuths: [Double]   // 25 values: hour 0-24 (24 is next day midnight for interpolation)
        let altitudes: [Double]  // 25 values
    }
    
    // Wrapper class for NSCache (NSCache requires reference types)
    private class HourlySunDataWrapper {
        let data: HourlySunData
        init(_ data: HourlySunData) { self.data = data }
    }
    
    // Thread-safe, lock-free cache using NSCache
    private static let sunDataCache: NSCache<NSString, HourlySunDataWrapper> = {
        let cache = NSCache<NSString, HourlySunDataWrapper>()
        cache.countLimit = 60 // Keep last 60 entries
        return cache
    }()
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }
    
    // Interpolated sun position based on cached hourly data
    private var sunAzimuthData: (azimuth: Double, altitude: Double) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let hourlyData = cachedHourlySunData(for: date)
        
        // Get fractional hour for interpolation
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let fractionalHour = hour + minute / 60.0 + second / 3600.0
        
        // Interpolate between hourly values
        let lowerHour = Int(fractionalHour)
        let upperHour = min(lowerHour + 1, 24)
        let t = fractionalHour - Double(lowerHour)
        
        // Handle azimuth wraparound (e.g., 350° to 10° should go through 360°/0°)
        var azimuth1 = hourlyData.azimuths[lowerHour]
        var azimuth2 = hourlyData.azimuths[upperHour]
        
        // If the difference is more than 180°, we need to wrap around
        if azimuth2 - azimuth1 > 180 {
            azimuth1 += 360
        } else if azimuth1 - azimuth2 > 180 {
            azimuth2 += 360
        }
        
        var interpolatedAzimuth = azimuth1 + (azimuth2 - azimuth1) * t
        // Normalize to 0-360
        if interpolatedAzimuth >= 360 {
            interpolatedAzimuth -= 360
        } else if interpolatedAzimuth < 0 {
            interpolatedAzimuth += 360
        }
        
        let interpolatedAltitude = hourlyData.altitudes[lowerHour] + (hourlyData.altitudes[upperHour] - hourlyData.altitudes[lowerHour]) * t
        
        return (interpolatedAzimuth, interpolatedAltitude)
    }
    
    // Get (or compute) hourly sun data for the given day and timezone
    private func cachedHourlySunData(for date: Date) -> HourlySunData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = Self.sunDataCache.object(forKey: cacheKey) {
            return cached.data
        }
        
        let startOfDay = calendar.startOfDay(for: date)
        var azimuths: [Double] = []
        var altitudes: [Double] = []
        
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)
            
            // Calculate for each hour (0-24)
            for hour in 0...24 {
                let hourDate = startOfDay.addingTimeInterval(Double(hour) * 3600)
                sun.setDate(hourDate)
                azimuths.append(sun.azimuth.degrees)
                altitudes.append(sun.altitude.degrees)
            }
        } else {
            // Fallback: estimate based on time of day
            for hour in 0...24 {
                let h = Double(hour)
                let azimuth: Double
                if h < 6 {
                    azimuth = 90.0 - (h / 6.0) * 90.0
                } else if h < 12 {
                    azimuth = 90.0 + ((h - 6.0) / 6.0) * 90.0
                } else if h < 18 {
                    azimuth = 180.0 + ((h - 12.0) / 6.0) * 90.0
                } else {
                    azimuth = 270.0 + ((h - 18.0) / 6.0) * 90.0
                }
                azimuths.append(azimuth.truncatingRemainder(dividingBy: 360))
                altitudes.append(h > 6 && h < 18 ? 30 : -30)
            }
        }
        
        let data = HourlySunData(azimuths: azimuths, altitudes: altitudes)
        
        // Store in cache (NSCache handles size limits automatically)
        Self.sunDataCache.setObject(HourlySunDataWrapper(data), forKey: cacheKey)
        
        return data
    }
    
    var body: some View {
        // Use interpolated data for smooth animation
        let data = sunAzimuthData
        let isSunVisible = data.altitude > 0
        let sunRadius: CGFloat = size * 0.15
        let orbitRadius: CGFloat = size * 0.35
        
        // Convert azimuth to rotation angle
        // 0° azimuth = North = top = -90° in SwiftUI coordinate system
        // We want North at top, so we need to adjust
        let rotationAngle = SwiftUI.Angle(degrees: data.azimuth)
        
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
            
            // Cross lines (combined)
            Path { path in
                let center = size / 2
                let halfLength = size * 0.175
                // Vertical line
                path.move(to: CGPoint(x: center, y: center - halfLength))
                path.addLine(to: CGPoint(x: center, y: center + halfLength))
                // Horizontal line
                path.move(to: CGPoint(x: center - halfLength, y: center))
                path.addLine(to: CGPoint(x: center + halfLength, y: center))
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .blendMode(.plusLighter)
            
//            // North Indicator
//            Circle()
//                .fill(.white.opacity(0.25))
//                .frame(width: 3, height: 3)
//                .offset(y: -size * 0.35)
//                .blendMode(.plusLighter)
            
            // Sun Indicator
            ZStack {
                // Sun circle
                Circle()
                    .fill(isSunVisible ? .white : .clear)
                    .frame(width: sunRadius, height: sunRadius)
                
                // Stroke when below horizon
                if !isSunVisible {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1.50)
                        .frame(width: sunRadius, height: sunRadius)
                }
            }
            .blendMode(.plusLighter)
            .offset(y: -orbitRadius)
            .rotationEffect(rotationAngle)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            HStack(spacing: 40) {
                SunAzimuthIndicator(
                    date: Date(),
                    timeZone: .current,
                    size: 64
                )
                
                SunAzimuthIndicator(
                    date: Date(),
                    timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current,
                    size: 64
                )
            }
        }
    }
}

