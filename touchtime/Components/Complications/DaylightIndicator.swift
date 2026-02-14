//
//  DaylightIndicator.swift
//  touchtime
//
//  Created on 14/01/2026.
//
//  Daylight progress: arc shows how many hours of daylight have passed (sunrise → now).
//  White = elapsed daylight, dark gray = remaining daylight.
//

import SwiftUI
import SunKit
import CoreLocation

struct DaylightIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    
    private struct SunTimes {
        let sunrise: Date?
        let sunset: Date?
    }
    
    private class SunTimesWrapper {
        let times: SunTimes
        init(_ times: SunTimes) { self.times = times }
    }
    
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
    
    private func cachedSunTimes(for date: Date) -> SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_daylight_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        if let cached = DaylightIndicator.sunTimesCache.object(forKey: cacheKey) {
            return cached.times
        }
        
        let times: SunTimes
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)
            sun.setDate(date)
            times = SunTimes(sunrise: sun.sunrise, sunset: sun.sunset)
        } else {
            let startOfDay = calendar.startOfDay(for: date)
            times = SunTimes(
                sunrise: calendar.date(byAdding: .hour, value: 6, to: startOfDay),
                sunset: calendar.date(byAdding: .hour, value: 18, to: startOfDay)
            )
        }
        
        DaylightIndicator.sunTimesCache.setObject(SunTimesWrapper(times), forKey: cacheKey)
        return times
    }
    
    /// Progress through daylight: 0 = sunrise, 1 = sunset.
    /// Before sunrise: 0; after sunset: 1.
    private var daylightProgress: Double {
        let sunTimes = cachedSunTimes(for: date)
        guard let sunrise = sunTimes.sunrise, let sunset = sunTimes.sunset, sunset > sunrise else {
            return 0.5
        }
        
        if date <= sunrise { return 0 }
        if date >= sunset { return 1 }
        
        let daylightDuration = sunset.timeIntervalSince(sunrise)
        let elapsed = date.timeIntervalSince(sunrise)
        return max(0, min(1, elapsed / daylightDuration))
    }
    
    var body: some View {
        let progress = daylightProgress
        let lineWidth: CGFloat = size * 0.05
        
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
            
            
            // Inner arc: centered, inverted U (curves upward in the middle)
            GeometryReader { geo in
                let fullArc = topArcPath(in: geo.size)
                
                // Full arc background (dark gray - remaining)
                fullArc
                    .trimmedPath(from: 0, to: 1)
                    .stroke(
                        Color.white.opacity(0.10),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .blendMode(.plusLighter)
                
                // Progress arc (white - elapsed daylight)
                if progress > 0 {
                    fullArc
                        .trimmedPath(from: 0, to: progress)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blendMode(.plusLighter)
                }
            }
            .offset(y: -(size * 0.025))
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
    
    private func topArcPath(in size: CGSize) -> Path {
        let w = size.width
        let h = size.height
        let centerY = h * 0.56
        let horizontalInset = w * 0.24
        let arcLift = h * 0.18

        let start = CGPoint(x: horizontalInset, y: centerY)
        let end = CGPoint(x: w - horizontalInset, y: centerY)
        let control = CGPoint(x: w / 2, y: centerY - arcLift)

        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        HStack(spacing: 24) {
            DaylightIndicator(
                date: Date(),
                timeZone: .current,
                size: 100
            )
            
            // Simulate midday (full progress)
            DaylightIndicator(
                date: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
                timeZone: .current,
                size: 100
            )
        }
    }
}
