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

    private static let sampleCount = 96 // one sky sample every 15 minutes

    private var dayInterval: DateInterval {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: date, duration: 86400)
    }

    private var gradientColors: [Color] {
        let interval = dayInterval
        return (0...Self.sampleCount).map { index in
            let sampleDate = interval.start.addingTimeInterval(
                Double(index) / Double(Self.sampleCount) * interval.duration
            )
            let stops = SkyColorGradient(
                date: sampleDate,
                timeZoneIdentifier: timeZoneIdentifier
            ).colors
            // Blend the mid-sky and lower-sky stops so daytime stays blue
            // while sunrise/sunset keep their warm horizon glow.
            return stops[2].mix(with: stops[3], by: 0.5)
        }
    }

    private var dayProgress: Double {
        let interval = dayInterval
        guard interval.duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(interval.start) / interval.duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let indicatorSize: CGFloat = 20 // Circle
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
                    .frame(height: 36)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.05), lineWidth: 1)
                            .blendMode(.plusLighter)
                    }

                // Sun position indicator
                Circle()
                    .fill(.white)
                    .frame(width: indicatorSize, height: indicatorSize)
//                    .overlay {
//                        Circle()
//                            .stroke(.black.opacity(0.10), lineWidth: 1)
//                            .blendMode(.plusDarker)
//                    }
                    .offset(x: sunOffset)
                    .animation(.spring(), value: dayProgress)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
