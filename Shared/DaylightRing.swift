//
//  DaylightRing.swift
//  touchtime
//
//  24-hour sky ring: the Daylight sheet's horizontal timeline bent into a
//  circle. Same sampling and smoothing as DaylightIndicatorBar, mapped with
//  the app's 24-hour circular convention (00:00 at top, clockwise).
//  Shared between the Daylight widget and the app's widget intro sheet.
//

import SwiftUI

struct DaylightRing: View {
    let date: Date
    let timeZoneIdentifier: String
    let size: CGFloat
    let ringWidth: CGFloat
    // Tinted/clear home screens and StandBy flatten every color to a single
    // accent shade, turning the sky gradient into a solid donut. In those
    // modes draw an opacity-only ring instead.
    let monochrome: Bool

    @Environment(\.colorScheme) private var colorScheme

    private static let sampleCount = 288 // one sky sample every 5 minutes
    // Gaussian smoothing window (±30 min) applied to the sampled sky colors
    // in OKLab space, softening the night/twilight/day seams.
    private static let smoothingRadius = 6

    private struct RingStar: Identifiable {
        let id: Int
        let x: CGFloat // fraction of the 24h day, i.e. angular position
        let y: CGFloat // fraction across the ring width, outer -> inner
        let size: CGFloat
    }

    // Same fixed star field as the Daylight sheet's timeline
    // (DaylightIndicatorBar); both timeline ends are night and meet at the
    // top of the ring, so the dense ends cluster around midnight.
    private static let ringStars: [RingStar] = [
        .init(id: 0, x: 0.025, y: 0.22, size: 0.7),
        .init(id: 1, x: 0.055, y: 0.66, size: 0.55),
        .init(id: 2, x: 0.095, y: 0.38, size: 1.0),
        .init(id: 3, x: 0.135, y: 0.76, size: 0.65),
        .init(id: 4, x: 0.175, y: 0.18, size: 1.3),
        .init(id: 5, x: 0.310, y: 0.55, size: 0.55),
        .init(id: 6, x: 0.420, y: 0.25, size: 0.85),
        .init(id: 7, x: 0.540, y: 0.72, size: 0.6),
        .init(id: 8, x: 0.670, y: 0.42, size: 0.8),
        .init(id: 9, x: 0.810, y: 0.75, size: 0.65),
        .init(id: 10, x: 0.855, y: 0.31, size: 1.0),
        .init(id: 11, x: 0.900, y: 0.58, size: 0.6),
        .init(id: 12, x: 0.945, y: 0.20, size: 1.4),
        .init(id: 13, x: 0.980, y: 0.72, size: 0.8)
    ]

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

    // Star visibility around the ring, same sampling as the sheet's
    // timeline mask: white with SkyColorGradient.starOpacity per sample.
    private var starMaskColors: [Color] {
        let interval = dayInterval
        return (0...Self.sampleCount).map { index in
            let sampleDate = interval.start.addingTimeInterval(
                Double(index) / Double(Self.sampleCount) * interval.duration
            )
            let starOpacity = SkyColorGradient(
                date: sampleDate,
                timeZoneIdentifier: timeZoneIdentifier
            ).starOpacity
            return .white.opacity(starOpacity)
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

    // 1 = filled sun, 0 = outline sun. Outline only in the ring's night
    // band, i.e. past civil dawn/dusk; twilight, golden hour and day all
    // keep the filled disc. ±20 minute cross-fade at the boundary so the
    // per-minute timeline transitions smoothly.
    private var sunDaylightBlend: Double {
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) else {
            let fraction = dayFraction(of: date)
            return fraction >= 0.23 && fraction <= 0.77 ? 1 : 0
        }
        let events = SolarCalculator.events(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: date,
            timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current
        )
        // Polar night: events collapse to solar noon.
        guard events.civilDusk > events.civilDawn else { return 0 }

        let transitionWindow: TimeInterval = 20 * 60
        let dawnStart = events.civilDawn - transitionWindow
        let dawnEnd = events.civilDawn + transitionWindow
        let duskStart = events.civilDusk - transitionWindow
        let duskEnd = events.civilDusk + transitionWindow

        if date < dawnStart { return 0 }
        if date <= dawnEnd {
            let progress = date.timeIntervalSince(dawnStart) / (transitionWindow * 2)
            return min(max(progress, 0), 1)
        }
        if date < duskStart { return 1 }
        if date <= duskEnd {
            let progress = date.timeIntervalSince(duskStart) / (transitionWindow * 2)
            return min(max(1 - progress, 0), 1)
        }
        return 0
    }

    // Band opacities for the monochrome ring, night -> full day.
    private static let nightOpacity = 0.10
    private static let twilightOpacity = 0.20
    private static let goldenOpacity = 0.30
    private static let dayOpacity = 0.50
    
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

            // Stars over the night band, like the sheet's timeline. The mask
            // is the ring band itself filled with the angular star-visibility
            // gradient, so it fades the stars through twilight and clips
            // their glow to the band.
            ZStack {
                ForEach(Self.ringStars) { star in
                    let angle = star.x * 2 * .pi - .pi / 2
                    let radius = size / 2 - star.y * ringWidth
                    StarParticle(size: star.size)
                        .position(
                            x: size / 2 + radius * cos(angle),
                            y: size / 2 + radius * sin(angle)
                        )
                }
            }
            .frame(width: size, height: size)
            .mask {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: starMaskColors),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        lineWidth: ringWidth
                    )
            }
            .blendMode(.plusLighter)

            // Hairline edges, like the bar's subtle border in the sheet:
            // darkening on light backgrounds, lightening on dark ones.
            let edgeColor: Color = colorScheme == .dark ? .white : .black
            let edgeBlend: BlendMode = colorScheme == .dark ? .plusLighter : .plusDarker

            Circle()
                .strokeBorder(edgeColor.opacity(0.025), lineWidth: 1.0)
                .blendMode(edgeBlend)
            Circle()
                .inset(by: ringWidth)
                .stroke(edgeColor.opacity(0.025), lineWidth: 1.0)
                .blendMode(edgeBlend)
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
