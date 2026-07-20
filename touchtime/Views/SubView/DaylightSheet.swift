//
//  DaylightSheet.swift
//  touchtime
//
//  Created on 19/07/2026.
//

import SwiftUI
import Combine

struct DaylightSheet: View {
    let timeZoneIdentifier: String
    let timeOffset: TimeInterval

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var currentDate: Date = Date()

    // Timer to keep the sun indicator and countdown live
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var adjustedDate: Date {
        currentDate.addingTimeInterval(timeOffset)
    }

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    // Countdown to the next sunrise (day starts) or sunset (day ends)
    // in the city's timezone.
    private var countdownText: String? {
        guard let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) else {
            return nil
        }
        let now = adjustedDate
        let events = SolarCalculator.events(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: now,
            timeZone: timeZone
        )

        if now < events.sunrise {
            return String(format: String(localized: "Day starts in %@"), formatCountdown(events.sunrise.timeIntervalSince(now)))
        }
        if now < events.sunset {
            return String(format: String(localized: "Day ends in %@"), formatCountdown(events.sunset.timeIntervalSince(now)))
        }

        // After sunset: count down to tomorrow's sunrise.
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }
        let tomorrowEvents = SolarCalculator.events(
            latitude: coords.latitude,
            longitude: coords.longitude,
            date: tomorrow,
            timeZone: timeZone
        )
        return String(format: String(localized: "Day starts in %@"), formatCountdown(tomorrowEvents.sunrise.timeIntervalSince(now)))
    }

    private func formatCountdown(_ interval: TimeInterval) -> String {
        let totalMinutes = max(Int((interval / 60).rounded(.up)), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let hoursText = hours == 1
            ? String(localized: "1 hr")
            : String(format: String(localized: "%d hrs"), hours)
        let minutesText = minutes == 1
            ? String(localized: "1 min")
            : String(format: String(localized: "%d mins"), minutes)

        if hours == 0 { return minutesText }
        if minutes == 0 { return hoursText }
        return String(format: String(localized: "%@, %@"), hoursText, minutesText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DaylightIndicatorBar(
                    date: adjustedDate,
                    timeZoneIdentifier: timeZoneIdentifier
                )

                if let countdown = countdownText {
                    Text(countdown)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(), value: countdown)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .center)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Daylight")
                        .font(.headline)
                }
            }
            .onReceive(timer) { now in
                let calendar = Calendar.current
                if calendar.component(.minute, from: now) != calendar.component(.minute, from: currentDate) {
                    currentDate = now
                }
            }
            .presentationDetents([.height(250)])
        }
    }
}

// Horizontal 24-hour sky timeline: each x position shows the SkyColorGradient
// sampled at that local time, with a sun circle marking the current moment.
private struct DaylightIndicatorBar: View {
    let date: Date
    let timeZoneIdentifier: String

    private static let sampleCount = 288 // one sky sample every 5 minutes
    // Gaussian smoothing window (±30 min) applied to the sampled sky colors
    // in OKLab space, softening the night/twilight/day seams.
    private static let smoothingRadius = 6
    private static let barHeight: CGFloat = 36

    private struct TimelineStar: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    // Fixed positions keep the sparse field balanced across both nightly ends
    // of the 24-hour timeline.
    private static let timelineStars: [TimelineStar] = [
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
    // last sample, which is safe because both ends sit in stable night sky.
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

    private var dayProgress: Double {
        let interval = dayInterval
        guard interval.duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(interval.start) / interval.duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let indicatorSize: CGFloat = 22
            let sunOffset = (geometry.size.width - indicatorSize) * CGFloat(dayProgress)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width, height: Self.barHeight)

                ZStack {
                    ForEach(Self.timelineStars) { star in
                        StarParticle(size: star.size)
                            .position(
                                x: star.x * geometry.size.width,
                                y: star.y * Self.barHeight
                            )
                    }
                }
                .frame(width: geometry.size.width, height: Self.barHeight)
                .mask {
                    LinearGradient(
                        colors: starMaskColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .blendMode(.plusLighter)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .frame(width: geometry.size.width, height: Self.barHeight)

                // Sun position indicator
                Circle()
                    .fill(.white)
                    .frame(width: indicatorSize, height: indicatorSize)
                    .background {
                        // Shadow lives on its own layer: plusDarker on the
                        // white disc itself would make it vanish.
                        Circle()
                            .fill(.black.opacity(0.05))
                            .blur(radius: 5)
                            .offset(y: 2.5)
                            .blendMode(.plusDarker)
                    }
                    .offset(x: sunOffset)
                    .animation(.spring(), value: dayProgress)
            }
            .frame(width: geometry.size.width, height: Self.barHeight)
        }
        .frame(height: Self.barHeight)
    }
}
