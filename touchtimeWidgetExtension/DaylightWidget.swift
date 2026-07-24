//
//  DaylightWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: the city's 24-hour sky wrapped into a ring (same colors
//  as the app's Daylight sheet), a sun indicator at the current time, and
//  the city's time and name in the center.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent

struct DaylightWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Daylight"
    static let description = IntentDescription("Choose a city to display.")

    @Parameter(title: "City")
    var city: CityEntity?
}

// MARK: - Timeline

struct DaylightWidgetEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let timeZoneIdentifier: String
    let use24Hour: Bool
}

struct DaylightWidgetProvider: AppIntentTimelineProvider {
    // Only honour the configured city if it still exists in the app's saved
    // list; otherwise (deleted in the app) fall back to the first saved city.
    private func resolveCity(for configuration: DaylightWidgetIntent) -> CityEntity? {
        let savedCities = SharedWidgetStore.loadWorldClocks().map { CityEntity(clock: $0) }
        if let selected = configuration.city,
           savedCities.contains(where: { $0.id == selected.id }) {
            return selected
        }
        return savedCities.first
    }

    private func makeEntry(city: CityEntity?, date: Date) -> DaylightWidgetEntry {
        DaylightWidgetEntry(
            date: date,
            cityName: city?.cityName ?? "London",
            timeZoneIdentifier: city?.timeZoneIdentifier ?? "Europe/London",
            use24Hour: SharedWidgetStore.use24HourFormat()
        )
    }

    func placeholder(in context: Context) -> DaylightWidgetEntry {
        DaylightWidgetEntry(
            date: Date(),
            cityName: "London",
            timeZoneIdentifier: "Europe/London",
            use24Hour: false
        )
    }

    func snapshot(for configuration: DaylightWidgetIntent, in context: Context) async -> DaylightWidgetEntry {
        makeEntry(city: resolveCity(for: configuration), date: Date())
    }

    func timeline(for configuration: DaylightWidgetIntent, in context: Context) async -> Timeline<DaylightWidgetEntry> {
        let city = resolveCity(for: configuration)

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        // One entry per minute for the next hour, aligned to minute boundaries
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let start = calendar.date(from: components) ?? now

        var entries: [DaylightWidgetEntry] = []
        for minuteOffset in 0..<60 {
            if let date = calendar.date(byAdding: .minute, value: minuteOffset, to: start) {
                entries.append(makeEntry(city: city, date: date))
            }
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct DaylightWidgetView: View {
    var entry: DaylightWidgetEntry

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var timeZone: TimeZone {
        TimeZone(identifier: entry.timeZoneIdentifier) ?? .current
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = entry.use24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: entry.date)
    }

    // City-local date via the app's shared formatter, weekday omitted.
    private var dateString: String {
        entry.date.formattedDate(style: "Date Only", timeZone: timeZone)
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let ringWidth = side * 0.20
            let holeDiameter = side - ringWidth * 2

            ZStack {
                DaylightRing(
                    date: entry.date,
                    timeZoneIdentifier: entry.timeZoneIdentifier,
                    size: side,
                    ringWidth: ringWidth,
                    monochrome: renderingMode != .fullColor
                )

                VStack(spacing: 0) {
                    Text(timeString)
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(dateString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: holeDiameter * 0.75)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            // Explicit white/black instead of systemBackground: widgets can
            // resolve the "elevated" dark variant (#1C1C1E) otherwise.
            colorScheme == .dark ? Color.black : Color.white
        }
    }
}

// 24-hour sky ring: the Daylight sheet's horizontal timeline bent into a
// circle. Same sampling and smoothing as DaylightIndicatorBar, mapped with
// the app's 24-hour circular convention (00:00 at top, clockwise).
private struct DaylightRing: View {
    let date: Date
    let timeZoneIdentifier: String
    let size: CGFloat
    let ringWidth: CGFloat
    // Tinted/clear home screens and StandBy flatten every color to a single
    // accent shade, turning the sky gradient into a solid donut. In those
    // modes draw an opacity-only ring instead.
    let monochrome: Bool

    private static let sampleCount = 288 // one sky sample every 5 minutes
    // Gaussian smoothing window (±30 min) applied to the sampled sky colors
    // in OKLab space, softening the night/twilight/day seams.
    private static let smoothingRadius = 6

    private var dayInterval: DateInterval {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: date, duration: 86400)
    }

    private var gradientColors: [Color] {
        let interval = dayInterval
        let samples: [SIMD3<Double>] = (0...Self.sampleCount).map { index in
            let sampleDate = interval.start.addingTimeInterval(
                Double(index) / Double(Self.sampleCount) * interval.duration
            )
            let stops = SkyColorGradient(
                date: sampleDate,
                timeZoneIdentifier: timeZoneIdentifier
            ).oklabStops
            // Blend the mid-sky and lower-sky stops so daytime stays blue
            // while sunrise/sunset keep their warm horizon glow.
            return (stops[2] + stops[3]) * 0.5
        }
        return Self.gaussianSmoothed(samples).map { SkyColorGradient.color(fromOKLab: $0) }
    }

    // Gaussian blur along the time axis, performed in OKLab so hues blend
    // perceptually instead of dipping through gray. Edges clamp to the first/
    // last sample, which is safe because both ends sit in stable night sky
    // (and coincide at the top of the ring).
    private static func gaussianSmoothed(_ samples: [SIMD3<Double>]) -> [SIMD3<Double>] {
        let radius = smoothingRadius
        guard radius > 0, samples.count > 1 else { return samples }

        let sigma = Double(radius) / 2.0
        let weights = (-radius...radius).map { offset in
            exp(-Double(offset * offset) / (2.0 * sigma * sigma))
        }
        let totalWeight = weights.reduce(0, +)

        return samples.indices.map { index in
            var sum = SIMD3<Double>()
            for (weightIndex, offset) in (-radius...radius).enumerated() {
                let neighbor = min(max(index + offset, 0), samples.count - 1)
                sum += samples[neighbor] * weights[weightIndex]
            }
            return sum / totalWeight
        }
    }

    // Fraction of the local day (0 = midnight, 1 = next midnight), i.e. the
    // angular position on the ring.
    private func dayFraction(of target: Date) -> Double {
        let interval = dayInterval
        guard interval.duration > 0 else { return 0 }
        return min(max(target.timeIntervalSince(interval.start) / interval.duration, 0), 1)
    }

    private var dayProgress: Double {
        dayFraction(of: date)
    }

    // 1 = day (filled sun), 0 = night (outline sun), cross-fading through
    // the same ±20 minute sunrise/sunset window as the app's
    // DaylightIndicator complication.
    private var sunDaylightBlend: Double {
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) else {
            let fraction = dayFraction(of: date)
            return fraction >= 0.25 && fraction <= 0.75 ? 1 : 0
        }
        let events = SolarCalculator.events(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: date,
            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current
        )
        // Polar night: events collapse to solar noon.
        guard events.sunset > events.sunrise else { return 0 }

        let transitionWindow: TimeInterval = 20 * 60
        let sunriseStart = events.sunrise - transitionWindow
        let sunriseEnd = events.sunrise + transitionWindow
        let sunsetStart = events.sunset - transitionWindow
        let sunsetEnd = events.sunset + transitionWindow

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

    // Band opacities for the monochrome ring, night -> full day.
    private static let nightOpacity = 0.10
    private static let twilightOpacity = 0.20
    private static let goldenOpacity = 0.30
    private static let dayOpacity = 0.50

//    private static let nightOpacity = 0.15
//    private static let twilightOpacity = 0.3
//    private static let goldenOpacity = 0.45
//    private static let dayOpacity = 0.6

    
    // Hard-edged opacity bands mirroring the full-color ring's phases:
    // night / civil twilight / golden hour / day, split at civil dawn+dusk,
    // sunrise+sunset and the +6-degree golden-hour boundaries.
    private var monochromeStops: [Gradient.Stop] {
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) else {
            return Self.monochromeStops(boundaries: [0.23, 0.25, 0.29, 0.71, 0.75, 0.77])
        }
        let events = SolarCalculator.events(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: date,
            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current
        )
        // Morning golden-hour end (+6 degrees) isn't in DayEvents; mirror the
        // evening crossing around solar noon (declination drift within one
        // day is negligible).
        let morningGoldenHourEnd = events.solarNoon.addingTimeInterval(
            -events.eveningGoldenHourStart.timeIntervalSince(events.solarNoon)
        )
        let boundaries = [
            events.civilDawn,
            events.sunrise,
            morningGoldenHourEnd,
            events.eveningGoldenHourStart,
            events.sunset,
            events.civilDusk
        ].map { dayFraction(of: $0) }
        return Self.monochromeStops(boundaries: boundaries)
    }

    // Duplicated stop locations produce hard band edges. Boundaries are
    // clamped monotonic so degenerate polar-day/night bands just collapse.
    private static func monochromeStops(boundaries: [Double]) -> [Gradient.Stop] {
        let bands = [
            nightOpacity, twilightOpacity, goldenOpacity,
            dayOpacity,
            goldenOpacity, twilightOpacity, nightOpacity
        ]
        var stops: [Gradient.Stop] = [.init(color: .white.opacity(bands[0]), location: 0)]
        var previous = 0.0
        for (index, boundary) in boundaries.enumerated() {
            let location = min(max(boundary, previous), 1)
            stops.append(.init(color: .white.opacity(bands[index]), location: location))
            stops.append(.init(color: .white.opacity(bands[index + 1]), location: location))
            previous = location
        }
        stops.append(.init(color: .white.opacity(bands[bands.count - 1]), location: 1))
        return stops
    }

    var body: some View {
        let ringRadius = (size - ringWidth) / 2
        let sunSize = ringWidth * 0.60
        let sunAngle = dayProgress * 2 * .pi - .pi / 2
        let sunCenter = CGPoint(
            x: size / 2 + ringRadius * cos(sunAngle),
            y: size / 2 + ringRadius * sin(sunAngle)
        )

        ZStack {
            if monochrome {
                monochromeRing
            } else {
                fullColorRing
            }

            // Sun position indicator: filled disc by day, outline at night,
            // like the app's DaylightIndicator complication.
            let sunBlend = sunDaylightBlend
            ZStack {
                Circle()
                    .fill(.white)
                    .background {
                        if !monochrome {
                            // Shadow lives on its own layer: plusDarker on the
                            // white disc itself would make it vanish.
                            Circle()
                                .fill(.black.opacity(0.05))
                                .blur(radius: 5)
                                .offset(y: 2.5)
                                .blendMode(.plusDarker)
                        }
                    }
                    .opacity(sunBlend)

                Circle()
                    .stroke(.white, lineWidth: 2.0)
                    .opacity((1 - sunBlend) * 0.35)
                    .blendMode(.plusLighter)
            }
            .frame(width: sunSize, height: sunSize)
            .position(sunCenter)
        }
        .frame(width: size, height: size)
    }

    private var fullColorRing: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    lineWidth: ringWidth
                )

            // Hairline edges, like the bar's subtle border in the sheet.
            Circle()
                .strokeBorder(.white.opacity(0.05), lineWidth: 1)
                .blendMode(.plusLighter)
            Circle()
                .inset(by: ringWidth)
                .stroke(.white.opacity(0.05), lineWidth: 1)
                .blendMode(.plusLighter)
        }
    }

    // Accent-color rendering keeps only opacity, so encode the day with it:
    // stepped bands from dim night up to bright day, segmented at civil
    // twilight, sunrise/sunset and the golden-hour boundaries.
    private var monochromeRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: monochromeStops),
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(270)
                ),
                lineWidth: ringWidth
            )
    }
}

// MARK: - Widget

struct DaylightWidget: Widget {
    let kind: String = "DaylightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: DaylightWidgetIntent.self,
            provider: DaylightWidgetProvider()
        ) { entry in
            DaylightWidgetView(entry: entry)
        }
        .configurationDisplayName("Daylight")
        .description("Shows a city's time at the center of its 24-hour sky ring.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
