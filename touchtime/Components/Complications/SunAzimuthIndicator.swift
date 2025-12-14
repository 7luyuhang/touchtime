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
    
    // Cache sun azimuth per timezone to avoid repeated SunKit calculations
    private struct SunAzimuthData {
        let azimuth: Double // in degrees, 0 = North, clockwise
        let altitude: Double // for determining if sun is visible
    }
    
    // Use NSCache for thread-safe, efficient caching without blocking main thread
    private static let azimuthCache = NSCache<NSString, SunAzimuthDataWrapper>()
    
    // Wrapper class for NSCache (requires class type)
    private final class SunAzimuthDataWrapper {
        let data: SunAzimuthData
        init(_ data: SunAzimuthData) {
            self.data = data
        }
    }
    
    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        
        // Configure cache limit
        Self.azimuthCache.countLimit = 120
    }
    
    // Calculate sun azimuth using SunKit - computed once and stored
    private func calculateSunAzimuthData() -> SunAzimuthData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        // Cache key updates every 10 minutes (sufficient for sun azimuth visual accuracy ~1px)
        let minuteSlot = (components.minute ?? 0) / 10
        let cacheKey = "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)_\(components.hour ?? 0)_\(minuteSlot)" as NSString
        
        // Return cached value if present (NSCache is thread-safe, no lock needed)
        if let cached = Self.azimuthCache.object(forKey: cacheKey) {
            return cached.data
        }
        
        let data: SunAzimuthData
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)
            sun.setDate(date)
            
            // SunKit provides azimuth in Radians, convert to degrees
            let azimuthDegrees = sun.azimuth.degrees
            let altitudeDegrees = sun.altitude.degrees
            
            data = SunAzimuthData(azimuth: azimuthDegrees, altitude: altitudeDegrees)
        } else {
            // Fallback: estimate based on time of day
            let hour = Double(components.hour ?? 12) + Double(components.minute ?? 0) / 60.0
            // Rough approximation: sun moves from East (6am) to South (noon) to West (6pm)
            // This is a simplified linear interpolation
            let azimuth: Double
            if hour < 6 {
                azimuth = 90.0 - (hour / 6.0) * 90.0 // Night, east side
            } else if hour < 12 {
                azimuth = 90.0 + ((hour - 6.0) / 6.0) * 90.0 // Morning, moving to south
            } else if hour < 18 {
                azimuth = 180.0 + ((hour - 12.0) / 6.0) * 90.0 // Afternoon, moving to west
            } else {
                azimuth = 270.0 + ((hour - 18.0) / 6.0) * 90.0 // Evening, moving to north
            }
            data = SunAzimuthData(azimuth: azimuth, altitude: hour > 6 && hour < 18 ? 30 : -30)
        }
        
        // Store in cache (NSCache handles limits automatically)
        Self.azimuthCache.setObject(SunAzimuthDataWrapper(data), forKey: cacheKey)
        
        return data
    }
    
    var body: some View {
        // Calculate data once for the entire body
        let data = calculateSunAzimuthData()
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
            
            // Vertical line
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: 1.5, height: size * 0.35)
                .blendMode(.plusLighter)
            
            // Horizontal line
            Capsule()
                .fill(.white.opacity(0.25))
                .frame(width: size * 0.35 , height: 1.5)
                .blendMode(.plusLighter)
            
            // North Indicator
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 3, height: 3)
                .offset(y: -size * 0.35)
                .blendMode(.plusLighter)
            
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

