//
//  MoonAzimuthIndicator.swift
//  touchtime
//
//  Created on 04/03/2026.
//

import SwiftUI
import MoonKit
import CoreLocation

struct MoonAzimuthIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    private let previewAzimuthDegrees: Double?
    private let previewAltitudeDegrees: Double?
    private let previewPhase: MoonPhase?

    private struct HourlyMoonData {
        let azimuths: [Double]
        let altitudes: [Double]
        let phases: [MoonPhase]
    }

    private final class HourlyMoonDataWrapper {
        let data: HourlyMoonData

        init(_ data: HourlyMoonData) {
            self.data = data
        }
    }

    private static let moonDataCache: NSCache<NSString, HourlyMoonDataWrapper> = {
        let cache = NSCache<NSString, HourlyMoonDataWrapper>()
        cache.countLimit = 60
        return cache
    }()

    init(
        date: Date,
        timeZone: TimeZone,
        size: CGFloat,
        useMaterialBackground: Bool = false,
        previewAzimuthDegrees: Double? = nil,
        previewAltitudeDegrees: Double? = nil,
        previewPhase: MoonPhase? = nil
    ) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
        self.previewAzimuthDegrees = previewAzimuthDegrees
        self.previewAltitudeDegrees = previewAltitudeDegrees
        self.previewPhase = previewPhase
    }

    private var moonAzimuthData: (azimuth: Double, altitude: Double, phase: MoonPhase) {
        if let previewAzimuthDegrees {
            return (
                previewAzimuthDegrees.truncatingRemainder(dividingBy: 360),
                previewAltitudeDegrees ?? 45,
                previewPhase ?? .fullMoon
            )
        }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let hourlyData = cachedHourlyMoonData(for: date)
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let fractionalHour = hour + minute / 60.0 + second / 3600.0

        let lowerHour = Int(fractionalHour)
        let upperHour = min(lowerHour + 1, 24)
        let t = fractionalHour - Double(lowerHour)

        var azimuth1 = hourlyData.azimuths[lowerHour]
        var azimuth2 = hourlyData.azimuths[upperHour]

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

        let interpolatedAltitude = hourlyData.altitudes[lowerHour]
            + (hourlyData.altitudes[upperHour] - hourlyData.altitudes[lowerHour]) * t

        return (
            interpolatedAzimuth,
            interpolatedAltitude,
            hourlyData.phases[lowerHour]
        )
    }

    private func cachedHourlyMoonData(for date: Date) -> HourlyMoonData {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_moon_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString

        if let cached = Self.moonDataCache.object(forKey: cacheKey) {
            return cached.data
        }

        let startOfDay = calendar.startOfDay(for: date)
        var azimuths: [Double] = []
        var altitudes: [Double] = []
        var phases: [MoonPhase] = []

        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let location = CLLocation(latitude: coords.latitude, longitude: coords.longitude)
            let moon = Moon(location: location, timeZone: timeZone)

            for hour in 0...24 {
                let hourDate = startOfDay.addingTimeInterval(Double(hour) * 3600)
                moon.setDate(hourDate)
                azimuths.append(moon.azimuth)
                altitudes.append(moon.altitude)
                phases.append(moon.currentMoonPhase)
            }
        } else {
            for hour in 0...24 {
                let progress = Double(hour) / 24.0
                azimuths.append((progress * 360.0).truncatingRemainder(dividingBy: 360))
                altitudes.append(sin(progress * 2 * .pi) * 30.0)
                phases.append(.fullMoon)
            }
        }

        let data = HourlyMoonData(azimuths: azimuths, altitudes: altitudes, phases: phases)
        Self.moonDataCache.setObject(HourlyMoonDataWrapper(data), forKey: cacheKey)
        return data
    }

    private func phaseSymbol(for phase: MoonPhase) -> String {
        switch phase {
        case .newMoon:
            return "moonphase.new.moon"
        case .waxingCrescent:
            return "moonphase.waxing.crescent"
        case .firstQuarter:
            return "moonphase.first.quarter"
        case .waxingGibbous:
            return "moonphase.waxing.gibbous"
        case .fullMoon:
            return "moonphase.full.moon"
        case .waningGibbous:
            return "moonphase.waning.gibbous"
        case .lastQuarter:
            return "moonphase.last.quarter"
        case .waningCrescent:
            return "moonphase.waning.crescent"
        case .error:
            return "moon.fill"
        }
    }

    var body: some View {
        let data = moonAzimuthData
        let isMoonVisible = data.altitude > 0
        let orbitRadius: CGFloat = size * 0.35
        let symbolSize = max(10, size * 0.185) // Moonphase symbol size
        let rotationAngle = SwiftUI.Angle(degrees: data.azimuth)

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

            Path { path in
                let center = size / 2
                let halfLength = size * 0.175
                path.move(to: CGPoint(x: center, y: center - halfLength))
                path.addLine(to: CGPoint(x: center, y: center + halfLength))
                path.move(to: CGPoint(x: center - halfLength, y: center))
                path.addLine(to: CGPoint(x: center + halfLength, y: center))
            }
            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .blendMode(.plusLighter)

            ZStack {
                Image(systemName: phaseSymbol(for: data.phase))
                    .font(.system(size: symbolSize, weight: .medium))
                    .foregroundStyle(.white.opacity(isMoonVisible ? 1.0 : 0.5))
                    .blendMode(.plusLighter)
                    .rotationEffect(.degrees(-data.azimuth))
                    .offset(y: -orbitRadius)
            }
                .rotationEffect(rotationAngle)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        HStack(spacing: 40) {
            MoonAzimuthIndicator(
                date: Date(),
                timeZone: .current,
                size: 64
            )

            MoonAzimuthIndicator(
                date: Date().addingTimeInterval(12 * 3600),
                timeZone: .current,
                size: 64
            )

            MoonAzimuthIndicator(
                date: Date(),
                timeZone: .current,
                size: 64,
                previewAzimuthDegrees: 0,
                previewAltitudeDegrees: 45,
                previewPhase: .newMoon
            )
        }
    }
}
