//
//  TimeOverlapIndicator.swift
//  touchtime
//
//  Created on 25/03/2026.
//

import SwiftUI

struct TimeOverlapIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    // 24-hour mapping: 0h at top, clockwise (15 degrees/hour)
    private func angleForDate(_ date: Date) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return Double(hour) * 15.0 + Double(minute) * 0.25
    }

    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        guard let date = Self.timeFormatter.date(from: timeString) else {
            return nil
        }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }
        return (hour, minute)
    }

    private func angleForTimeStringInTargetTimeZone(_ timeString: String) -> Double {
        guard let time = parseTimeString(timeString) else { return 0 }
        return Double(time.hour) * 15.0 + Double(time.minute) * 0.25
    }

    private func localAvailabilityDates(for referenceDate: Date) -> (start: Date, end: Date)? {
        guard let startTime = parseTimeString(availableStartTime),
              let endTime = parseTimeString(availableEndTime) else {
            return nil
        }

        var localCalendar = Calendar.current
        localCalendar.timeZone = .current

        guard let localStart = localCalendar.date(
            bySettingHour: startTime.hour,
            minute: startTime.minute,
            second: 0,
            of: referenceDate
        ) else {
            return nil
        }

        guard let localEndRaw = localCalendar.date(
            bySettingHour: endTime.hour,
            minute: endTime.minute,
            second: 0,
            of: referenceDate
        ) else {
            return nil
        }

        let localEnd: Date
        if localEndRaw <= localStart {
            localEnd = localCalendar.date(byAdding: .day, value: 1, to: localEndRaw) ?? localEndRaw
        } else {
            localEnd = localEndRaw
        }

        return (start: localStart, end: localEnd)
    }

    private func isAngleOnArc(current: Double, start: Double, end: Double) -> Bool {
        let normalizedStart = start.truncatingRemainder(dividingBy: 360)
        let normalizedEnd = end.truncatingRemainder(dividingBy: 360)
        let normalizedCurrent = current.truncatingRemainder(dividingBy: 360)

        let adjustedEnd = normalizedEnd <= normalizedStart ? normalizedEnd + 360 : normalizedEnd
        let adjustedCurrent = normalizedCurrent < normalizedStart ? normalizedCurrent + 360 : normalizedCurrent

        return adjustedCurrent >= normalizedStart && adjustedCurrent <= adjustedEnd
    }

    var body: some View {
        let availability = localAvailabilityDates(for: date)
        let startAngle = availability.map { angleForDate($0.start) } ?? angleForTimeStringInTargetTimeZone(availableStartTime)
        let endAngle = availability.map { angleForDate($0.end) } ?? angleForTimeStringInTargetTimeZone(availableEndTime)
        let currentAngle = angleForDate(date)
        let isCurrentOnArc = isAngleOnArc(current: currentAngle, start: startAngle, end: endAngle)

        let orbitRadius: CGFloat = size * 0.375
        let lineWidth: CGFloat = size * 0.125
        let markerSize: CGFloat = size * 0.125

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

            TimeOverlapOrbitArc(
                startAngle: startAngle,
                endAngle: endAngle,
                size: size,
                orbitRadius: orbitRadius,
                lineWidth: lineWidth
            )

            Circle()
                .fill(.white)
                .opacity(isCurrentOnArc ? 1.0 : 0.50)
                .frame(width: markerSize, height: markerSize)
                .offset(y: -orbitRadius)
                .rotationEffect(.degrees(currentAngle))
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct TimeOverlapOrbitArc: View {
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat
    let orbitRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let adjustedEndAngle = endAngle <= startAngle ? endAngle + 360 : endAngle
        let startRadians = (startAngle - 90) * .pi / 180
        let endRadians = (adjustedEndAngle - 90) * .pi / 180

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
            Color.white.opacity(0.10),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        .blendMode(.plusLighter)
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 24) {
            TimeOverlapIndicator(
                date: Date(),
                timeZone: .current,
                size: 64
            )

            TimeOverlapIndicator(
                date: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date(),
                timeZone: .current,
                size: 64
            )
        }
    }
}
