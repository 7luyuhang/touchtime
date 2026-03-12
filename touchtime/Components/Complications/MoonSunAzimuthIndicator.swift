//
//  MoonSunAzimuthIndicator.swift
//  touchtime
//
//  Created on 12/03/2026.
//

import SwiftUI
import SunKit
import MoonKit
import CoreLocation

struct MoonSunAzimuthIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    private struct HourlySunData {
        let azimuths: [Double]
        let altitudes: [Double]
    }

    private struct HourlyMoonData {
        let azimuths: [Double]
        let altitudes: [Double]
    }

    private final class HourlySunDataWrapper {
        let data: HourlySunData

        init(_ data: HourlySunData) {
            self.data = data
        }
    }

    private final class HourlyMoonDataWrapper {
        let data: HourlyMoonData

        init(_ data: HourlyMoonData) {
            self.data = data
        }
    }

    private static let sunDataCache: NSCache<NSString, HourlySunDataWrapper> = {
        let cache = NSCache<NSString, HourlySunDataWrapper>()
        cache.countLimit = 60
        return cache
    }()

    private static let moonDataCache: NSCache<NSString, HourlyMoonDataWrapper> = {
        let cache = NSCache<NSString, HourlyMoonDataWrapper>()
        cache.countLimit = 60
        return cache
    }()

    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    private var sunAzimuthData: (azimuth: Double, altitude: Double) {
        let hourlyData = cachedHourlySunData(for: date)
        return interpolatedAzimuthAltitude(from: hourlyData.azimuths, altitudes: hourlyData.altitudes)
    }

    private var moonAzimuthData: (azimuth: Double, altitude: Double) {
        let hourlyData = cachedHourlyMoonData(for: date)
        return interpolatedAzimuthAltitude(from: hourlyData.azimuths, altitudes: hourlyData.altitudes)
    }

    private func interpolatedAzimuthAltitude(from azimuths: [Double], altitudes: [Double]) -> (azimuth: Double, altitude: Double) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let fractionalHour = hour + minute / 60.0 + second / 3600.0

        let lowerHour = Int(fractionalHour)
        let upperHour = min(lowerHour + 1, 24)
        let t = fractionalHour - Double(lowerHour)

        var azimuth1 = azimuths[lowerHour]
        var azimuth2 = azimuths[upperHour]

        if azimuth2 - azimuth1 > 180 {
            azimuth1 += 360
        } else if azimuth1 - azimuth2 > 180 {
            azimuth2 += 360
        }

        var interpolatedAzimuth = azimuth1 + (azimuth2 - azimuth1) * t
        if interpolatedAzimuth >= 360 {
            interpolatedAzimuth -= 360
        } else if interpolatedAzimuth < 0 {
            interpolatedAzimuth += 360
        }

        let interpolatedAltitude = altitudes[lowerHour] + (altitudes[upperHour] - altitudes[lowerHour]) * t
        return (interpolatedAzimuth, interpolatedAltitude)
    }

    private func cachedHourlySunData(for date: Date) -> HourlySunData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_sun_moon_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString

        if let cached = Self.sunDataCache.object(forKey: cacheKey) {
            return cached.data
        }

        let startOfDay = calendar.startOfDay(for: date)
        var azimuths: [Double] = []
        var altitudes: [Double] = []

        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            var sun = Sun(location: location, timeZone: timeZone)

            for hour in 0...24 {
                let hourDate = startOfDay.addingTimeInterval(Double(hour) * 3600)
                sun.setDate(hourDate)
                azimuths.append(sun.azimuth.degrees)
                altitudes.append(sun.altitude.degrees)
            }
        } else {
            for hour in 0...24 {
                let progress = Double(hour) / 24.0
                azimuths.append((progress * 360.0).truncatingRemainder(dividingBy: 360))
                altitudes.append(sin(progress * 2 * .pi) * 30.0)
            }
        }

        let data = HourlySunData(azimuths: azimuths, altitudes: altitudes)
        Self.sunDataCache.setObject(HourlySunDataWrapper(data), forKey: cacheKey)
        return data
    }

    private func cachedHourlyMoonData(for date: Date) -> HourlyMoonData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_moon_sun_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString

        if let cached = Self.moonDataCache.object(forKey: cacheKey) {
            return cached.data
        }

        let startOfDay = calendar.startOfDay(for: date)
        var azimuths: [Double] = []
        var altitudes: [Double] = []

        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            let moon = Moon(location: location, timeZone: timeZone)

            for hour in 0...24 {
                let hourDate = startOfDay.addingTimeInterval(Double(hour) * 3600)
                moon.setDate(hourDate)
                azimuths.append(moon.azimuth)
                altitudes.append(moon.altitude)
            }
        } else {
            for hour in 0...24 {
                let progress = Double(hour) / 24.0
                azimuths.append((progress * 360.0).truncatingRemainder(dividingBy: 360))
                altitudes.append(cos(progress * 2 * .pi) * 30.0)
            }
        }

        let data = HourlyMoonData(azimuths: azimuths, altitudes: altitudes)
        Self.moonDataCache.setObject(HourlyMoonDataWrapper(data), forKey: cacheKey)
        return data
    }

    var body: some View {
        let sunData = sunAzimuthData
        let moonData = moonAzimuthData

        let isSunVisible = sunData.altitude > 0
        let isMoonVisible = moonData.altitude > 0

        let dividerRadius: CGFloat = size * 0.255
        let sunOrbitRadius: CGFloat = size * 0.375
        let moonOrbitRadius: CGFloat = size * 0.135
        let sunDotSize: CGFloat = max(6, size * 0.125)
        let moonDotSize: CGFloat = max(5, size * 0.125)
        let dividerLineWidth: CGFloat = max(1.5, size * 0.025)

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

            // Center line
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: dividerLineWidth)
                .frame(width: dividerRadius * 2, height: dividerRadius * 2)
                .blendMode(.plusLighter)

            // Sun (Outside)
            ZStack {
                if isSunVisible {
                    Circle()
                        .fill(.white)
                        .frame(width: sunDotSize, height: sunDotSize)
                } else {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: sunDotSize, height: sunDotSize)
                }
            }
            .blendMode(.plusLighter)
            .offset(y: -sunOrbitRadius)
            .rotationEffect(.degrees(sunData.azimuth))

            // Moon
            ZStack {
                if isMoonVisible {
                    Circle()
                        .fill(.white)
                        .frame(width: moonDotSize, height: moonDotSize)
                } else {
                    Circle()
                        .stroke(.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: moonDotSize, height: moonDotSize)
                }
            }
            .blendMode(.plusLighter)
            .offset(y: -moonOrbitRadius)
            .rotationEffect(.degrees(moonData.azimuth))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        MoonSunAzimuthIndicator(
            date: Date(),
            timeZone: TimeZone.current,
            size: 64
        )
    }
}
