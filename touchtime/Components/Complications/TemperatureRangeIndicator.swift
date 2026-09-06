//
//  TemperatureRangeIndicator.swift
//  touchtime
//
//  Created on 27/07/2026.
//

import SwiftUI

// Shows the day's temperature swing as a diurnal curve: the trough is the
// coolest moment (around sunrise), the peak is the warmest (mid-afternoon),
// and a dot travels along the curve marking the current time.
struct TemperatureRangeIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    // Layout constants shared by the curve and the dot (unit space)
    private static let centerY = 0.5
    private static let amplitude = 0.16 // Half of the curve's peak-to-trough height

    // Cache the Path to avoid recreating it on every body update
    @State private var cachedPath: Path?
    @State private var cachedDayKey: String = ""

    init(date: Date, timeZone: TimeZone = .current, size: CGFloat = 100, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    // MARK: - Diurnal model

    // Hours of the coolest and warmest moments of the day
    fileprivate struct Anchors {
        let minHour: Double
        let maxHour: Double
    }

    private class AnchorsWrapper {
        let anchors: Anchors
        init(_ anchors: Anchors) { self.anchors = anchors }
    }

    // Thread-safe, lock-free cache using NSCache (anchors only change per day)
    private static let anchorsCache: NSCache<NSString, AnchorsWrapper> = {
        let cache = NSCache<NSString, AnchorsWrapper>()
        cache.countLimit = 60
        return cache
    }()

    private static func hourOfDay(_ date: Date, timeZone: TimeZone) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    // Coolest moment ≈ sunrise, warmest ≈ 3h after solar noon (classic diurnal lag)
    fileprivate static func anchors(for date: Date, timeZone: TimeZone) -> Anchors {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(timeZone.identifier)_tempanchors_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString

        if let cached = anchorsCache.object(forKey: cacheKey) {
            return cached.anchors
        }

        var minHour = 6.0
        var maxHour = 15.0
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) {
            let events = SolarCalculator.events(latitude: coords.latitude, longitude: coords.longitude, date: date, timeZone: timeZone)
            minHour = hourOfDay(events.sunrise, timeZone: timeZone)
            maxHour = hourOfDay(events.solarNoon, timeZone: timeZone) + 3
        }

        // Keep the anchors ordered with a sensible gap, inside a single day
        minHour = min(max(minHour, 0), 12)
        maxHour = min(max(maxHour, minHour + 2), 23)

        let anchors = Anchors(minHour: minHour, maxHour: maxHour)
        anchorsCache.setObject(AnchorsWrapper(anchors), forKey: cacheKey)
        return anchors
    }

    // Normalized temperature at a given hour: 0 = daily low, 1 = daily high.
    // Piecewise cosine, periodic over 24h, so midnight joins yesterday's cooling.
    fileprivate static func temperatureFraction(hour: Double, anchors: Anchors) -> Double {
        let coolingDuration = 24 - anchors.maxHour + anchors.minHour
        if hour < anchors.minHour {
            // Overnight cooling, continuing from yesterday's peak
            let progress = (hour + 24 - anchors.maxHour) / coolingDuration
            return 0.5 + 0.5 * cos(.pi * progress)
        } else if hour <= anchors.maxHour {
            // Daytime warming
            let progress = (hour - anchors.minHour) / (anchors.maxHour - anchors.minHour)
            return 0.5 - 0.5 * cos(.pi * progress)
        } else {
            // Evening cooling towards tomorrow's sunrise low
            let progress = (hour - anchors.maxHour) / coolingDuration
            return 0.5 + 0.5 * cos(.pi * progress)
        }
    }

    private static func unitY(forFraction fraction: Double) -> Double {
        centerY + amplitude - 2 * amplitude * fraction
    }

    // Position at a given time in unit space (0...1). Uses the same mapping as
    // the curve points so the dot always sits on the curve.
    fileprivate static func unitPosition(for date: Date, timeZone: TimeZone) -> CGPoint {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let hour = date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
        let x = min(max(hour / 24, 0), 1)
        let fraction = temperatureFraction(hour: hour, anchors: anchors(for: date, timeZone: timeZone))
        return CGPoint(x: x, y: unitY(forFraction: fraction))
    }

    // MARK: - Path

    // Generate day key for caching (only changes when date changes, not time)
    private func dayKey(for date: Date) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(timeZone.identifier)_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)"
    }

    // Hourly samples through the day, in unit space
    private func curvePoints(for date: Date) -> [CGPoint] {
        let anchors = Self.anchors(for: date, timeZone: timeZone)
        return (0...24).map { hour in
            let fraction = Self.temperatureFraction(hour: Double(hour), anchors: anchors)
            return CGPoint(x: Double(hour) / 24, y: Self.unitY(forFraction: fraction))
        }
    }

    // Catmull-Rom spline converted to cubic Béziers, scaled from unit space to
    // the current size (same approach as SolarCurve).
    private func createPath(for date: Date) -> Path {
        var path = Path()
        let points = curvePoints(for: date).map { CGPoint(x: $0.x * size, y: $0.y * size) }
        guard points.count > 1 else { return path }

        path.move(to: points[0])

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

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

    var body: some View {
        // Use cached path if available, otherwise create empty path (will be set in onAppear/onChange)
        let curvePath = cachedPath ?? Path()
        let dotDiameter = size * 0.135

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

            // Temperature curve
            curvePath
                .stroke(
                    Color.white.opacity(0.8),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
                .blendMode(.plusLighter)

            // Dot at the current time position on the curve
            Circle()
                .fill(.white)
                .frame(width: dotDiameter, height: dotDiameter)
                .modifier(DotAlongTemperatureCurveModifier(date: date, timeZone: timeZone, size: size))
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(Circle()) // Ensure all content is clipped to circle boundary
        .onChange(of: date) { oldDate, newDate in
            // Only update path when day actually changes (not just time)
            let newDayKey = dayKey(for: newDate)
            if dayKey(for: oldDate) != newDayKey {
                cachedPath = createPath(for: newDate)
                cachedDayKey = newDayKey
            }
        }
        .onAppear {
            let currentDayKey = dayKey(for: date)
            if cachedPath == nil || cachedDayKey != currentDayKey {
                cachedPath = createPath(for: date)
                cachedDayKey = currentDayKey
            }
        }
    }
}

// MARK: - Dot Along Curve Modifier
// Positions the dot for a given time. Animating the time (not the x/y
// position) means that when a time change is animated (e.g. resetting a
// scrubbed time offset), the dot is re-evaluated on the curve every frame and
// travels along it, rather than sliding in a straight line.
//
// The time of day is animated as a point on the unit circle (cos, sin):
// reconstructing the angle with atan2 always sweeps the shorter way around,
// so no matter how many days the offset spans, the dot never laps the dial —
// at most half a day of travel, in the nearest direction.
private struct DotAlongTemperatureCurveModifier: ViewModifier, Animatable {
    var angle: AnimatablePair<Double, Double>
    let startOfDay: Date
    let timeZone: TimeZone
    let size: CGFloat

    private static let dayInSeconds: Double = 24 * 60 * 60

    init(date: Date, timeZone: TimeZone, size: CGFloat) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let startOfDay = calendar.startOfDay(for: date)
        let radians = date.timeIntervalSince(startOfDay) / Self.dayInSeconds * 2 * .pi
        self.angle = AnimatablePair(cos(radians), sin(radians))
        self.startOfDay = startOfDay
        self.timeZone = timeZone
        self.size = size
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { angle }
        set { angle = newValue }
    }

    // Angle back to a concrete position on the curve. Anchored to the currently
    // displayed day so the dot follows its curve.
    private var dotPoint: CGPoint {
        var radians = atan2(angle.second, angle.first)
        if radians < 0 { radians += 2 * .pi }
        let date = startOfDay.addingTimeInterval(radians / (2 * .pi) * Self.dayInSeconds)
        return TemperatureRangeIndicator.unitPosition(for: date, timeZone: timeZone)
    }

    func body(content: Content) -> some View {
        let point = dotPoint
        content.position(x: point.x * size, y: point.y * size)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        TemperatureRangeIndicator(
            date: Date(),
            timeZone: .current,
            size: 64
        )
    }
}
