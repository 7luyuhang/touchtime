//
//  DaylightIndicator.swift
//  touchtime
//
//  Created on 14/01/2026.
//
//  Daylight length: arc represents 24 hours. White = daylight (sunrise → sunset),
//  dark gray = night. Arc length of the white segment = hours of sunlight in the day.
//

import SwiftUI
import SunKit
import CoreLocation

struct DaylightIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    
    @State private var cachedSegment: (start: Double, end: Double) = (0.25, 0.75)
    @State private var cachedDayKey: String = ""
    
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
    
    private func dayKey(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(timeZone.identifier)_daylight_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)"
    }
    
    private func cachedSunTimes(for date: Date) -> SunTimes {
        let cacheKey = dayKey(for: date) as NSString
        
        if let cached = DaylightIndicator.sunTimesCache.object(forKey: cacheKey) {
            return cached.times
        }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
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
    
    private func computeSegment(for date: Date) -> (start: Double, end: Double) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)
        let dayInSeconds: Double = 24 * 60 * 60
        
        let sunTimes = cachedSunTimes(for: date)
        guard let sunrise = sunTimes.sunrise, let sunset = sunTimes.sunset, sunset > sunrise else {
            return (0.25, 0.75)
        }
        
        let sunriseProgress = max(0, min(1, sunrise.timeIntervalSince(startOfDay) / dayInSeconds))
        let sunsetProgress = max(0, min(1, sunset.timeIntervalSince(startOfDay) / dayInSeconds))
        return (sunriseProgress, sunsetProgress)
    }
    
    private func topArcPath() -> Path {
        let w = size
        let h = size
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
    
    var body: some View {
        let lineWidth: CGFloat = size * 0.04
        let fullArc = topArcPath()
        
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
            
            // Arc represents 24 hours. White = daylight, gray = night.
            ZStack {
                // Full arc background (gray - night)
                fullArc
                    .trimmedPath(from: 0, to: 1)
                    .stroke(
                        Color.white.opacity(0.20),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .blendMode(.plusLighter)
                
                // Daylight segment (white - sunrise to sunset)
                if cachedSegment.end - cachedSegment.start > 0 {
                    fullArc
                        .trimmedPath(from: cachedSegment.start, to: cachedSegment.end)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                        .blendMode(.plusLighter)
                }
            }
            .offset(y: -(size * 0.02))
            .frame(width: size, height: size)
            .drawingGroup()
        }
        .frame(width: size, height: size)
        .onChange(of: date) { oldDate, newDate in
            let oldKey = dayKey(for: oldDate)
            let newKey = dayKey(for: newDate)
            if oldKey != newKey {
                cachedSegment = computeSegment(for: newDate)
                cachedDayKey = newKey
            }
        }
        .onAppear {
            let currentKey = dayKey(for: date)
            if cachedDayKey != currentKey {
                cachedSegment = computeSegment(for: date)
                cachedDayKey = currentKey
            }
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
            
            // Same day - daylight length is identical (arc segment size doesn't change with time)
            DaylightIndicator(
                date: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
                timeZone: .current,
                size: 100
            )
        }
    }
}
