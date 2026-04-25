//
//  DaylightIndicator.swift
//  touchtime
//
//  Created on 14/01/2026.
//
//  Daylight Gradient complication:
//  - uses the same 24-hour circular mapping as SunriseSunsetIndicator
//  - only shows daylight arc (sunrise -> sunset) and the sun marker
//

import SwiftUI
import SunKit
import CoreLocation

struct DaylightIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    @State private var displayedSunDaylightBlend: Double = 0

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

    private var sunTimes: SunTimes {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_daylight_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString

        if let cached = Self.sunTimesCache.object(forKey: cacheKey) {
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

        Self.sunTimesCache.setObject(SunTimesWrapper(times), forKey: cacheKey)
        return times
    }

    // 24-hour mapping: 0h at top, clockwise (15 degrees/hour)
    private func angleForDate(_ date: Date?) -> Double? {
        guard let date else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Double(hour) * 15.0 + Double(minute) * 0.25
    }

    private func daylightBlend(sunrise: Date?, sunset: Date?) -> Double {
        guard let sunrise, let sunset, sunset > sunrise else { return 1 }

        // Cross-fade window around sunrise/sunset to avoid abrupt fill/stroke switching.
        let transitionWindow: TimeInterval = 20 * 60
        let sunriseStart = sunrise - transitionWindow
        let sunriseEnd = sunrise + transitionWindow
        let sunsetStart = sunset - transitionWindow
        let sunsetEnd = sunset + transitionWindow

        if date < sunriseStart { return 0 }
        if date <= sunriseEnd {
            let progress = date.timeIntervalSince(sunriseStart) / (transitionWindow * 2)
            return min(max(progress, 0), 1)
        }
        if date < sunsetStart { return 1 }
        if date <= sunsetEnd {
            let progress = date.timeIntervalSince(sunsetStart) / (transitionWindow * 2)
            return min(max(1 - progress, 0), 1)
        }
        return 0
    }

    // Only animate near sunrise/sunset when blend is transitioning.
    private func shouldAnimateBlend(sunrise: Date?, sunset: Date?) -> Bool {
        guard let sunrise, let sunset else { return false }
        let transitionWindow: TimeInterval = 20 * 60
        return abs(date.timeIntervalSince(sunrise)) <= transitionWindow
            || abs(date.timeIntervalSince(sunset)) <= transitionWindow
    }

    var body: some View {
        let times = sunTimes
        let sunriseAngle = angleForDate(times.sunrise)
        let sunsetAngle = angleForDate(times.sunset)
        let sunAngle = angleForDate(date)
        let sunDaylightBlend = daylightBlend(sunrise: times.sunrise, sunset: times.sunset)

        let orbitRadius: CGFloat = size * 0.375
        let lineWidth: CGFloat = size * 0.125
        let sunSize: CGFloat = size * 0.125

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

            if let sunriseAngle, let sunsetAngle {
                DaylightOrbitArc(
                    sunriseAngle: sunriseAngle,
                    sunsetAngle: sunsetAngle,
                    size: size,
                    orbitRadius: orbitRadius,
                    lineWidth: lineWidth
                )
                .opacity(0.50)
                .blur(radius: 1.5)
                .blendMode(.plusLighter)
                .drawingGroup()
            }

            if let sunAngle {
                ZStack {
                    Circle()
                        .fill(.white)
                        .opacity(displayedSunDaylightBlend)

                    Circle()
                        .stroke(.white, lineWidth: 1.5)
                        .opacity((1 - displayedSunDaylightBlend) * 0.5)
                }
                .frame(width: sunSize, height: sunSize)
                .offset(y: -orbitRadius)
                .rotationEffect(.degrees(sunAngle))
                .blendMode(.plusLighter)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            displayedSunDaylightBlend = sunDaylightBlend
        }
        .onChange(of: sunDaylightBlend) { _, newValue in
            guard newValue != displayedSunDaylightBlend else { return }
            if shouldAnimateBlend(sunrise: times.sunrise, sunset: times.sunset) {
                withAnimation(.spring()) {
                    displayedSunDaylightBlend = newValue
                }
            } else {
                displayedSunDaylightBlend = newValue
            }
        }
    }
}

private struct DaylightOrbitArc: View {
    let sunriseAngle: Double
    let sunsetAngle: Double
    let size: CGFloat
    let orbitRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let startRadians = (sunriseAngle - 90) * .pi / 180
        let endRadians = (sunsetAngle - 90) * .pi / 180

        Path { path in
            path.addArc(
                center: center,
                radius: orbitRadius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
        }
        .stroke(
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(1.0), location: 0.0),
                    .init(color: Color.white.opacity(0.50), location: 0.33),
                    .init(color: Color.white.opacity(0.25), location: 0.66),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ]),
                center: .center,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians)
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 24) {
            DaylightIndicator(
                date: Date(),
                timeZone: .current,
                size: 64
            )

            DaylightIndicator(
                date: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date(),
                timeZone: .current,
                size: 64
            )
        }
    }
}
