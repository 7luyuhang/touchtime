//
//  TimeOverlayIndicator.swift
//  touchtime
//
//  Created on 31/03/2026.
//

import SwiftUI

struct TimeOverlayIndicator: View {
    let date: Date
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool

    @AppStorage("availableStartTime") private var availableStartTime = AvailableTimeDefaults.startTime
    @AppStorage("availableEndTime") private var availableEndTime = AvailableTimeDefaults.endTime
    @AppStorage("availableWeekdays") private var availableWeekdays = AvailableTimeDefaults.weekdays

    fileprivate struct TimeRangeSegment: Hashable {
        let startMinute: Int
        let endMinute: Int
    }

    private final class SegmentsWrapper {
        let segments: [TimeRangeSegment]
        init(_ segments: [TimeRangeSegment]) {
            self.segments = segments
        }
    }

    private static let overlaySegmentsCache: NSCache<NSString, SegmentsWrapper> = {
        let cache = NSCache<NSString, SegmentsWrapper>()
        cache.countLimit = 240
        return cache
    }()

    init(date: Date, timeZone: TimeZone, size: CGFloat, useMaterialBackground: Bool = false) {
        self.date = date
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }

    private var selectedWeekdaySet: Set<Int> {
        let parsed = parseWeekdaySet(availableWeekdays)
        if parsed.isEmpty {
            return parseWeekdaySet(AvailableTimeDefaults.weekdays)
        }
        return parsed
    }

    private var parsedTimeRange: (startMinute: Int, endMinute: Int) {
        let defaultStartMinute = parseTimeStringToMinute(AvailableTimeDefaults.startTime) ?? (9 * 60)
        let defaultEndMinute = parseTimeStringToMinute(AvailableTimeDefaults.endTime) ?? (17 * 60)
        let startMinute = parseTimeStringToMinute(availableStartTime) ?? defaultStartMinute
        let endMinute = parseTimeStringToMinute(availableEndTime) ?? defaultEndMinute
        return (startMinute, endMinute)
    }

    private var overlaySegments: [TimeRangeSegment] {
        guard !selectedWeekdaySet.isEmpty else {
            return []
        }
        let range = parsedTimeRange

        let cacheKey = makeCacheKey(
            startMinute: range.startMinute,
            endMinute: range.endMinute,
            weekdays: selectedWeekdaySet
        )

        if let cached = Self.overlaySegmentsCache.object(forKey: cacheKey) {
            return cached.segments
        }

        let segments = calculateOverlaySegments(
            startMinute: range.startMinute,
            endMinute: range.endMinute,
            weekdays: selectedWeekdaySet
        )
        Self.overlaySegmentsCache.setObject(SegmentsWrapper(segments), forKey: cacheKey)
        return segments
    }

    private var isCurrentTimeInOverlay: Bool {
        guard !selectedWeekdaySet.isEmpty else {
            return false
        }
        let range = parsedTimeRange
        return isDateWithinLocalAvailability(
            at: date,
            startMinute: range.startMinute,
            endMinute: range.endMinute,
            weekdays: selectedWeekdaySet
        )
    }

    private var currentTimeAngle: Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return Double(hour) * 15 + Double(minute) * 0.25
    }

    private func makeCacheKey(startMinute: Int, endMinute: Int, weekdays: Set<Int>) -> NSString {
        var targetCalendar = Calendar.current
        targetCalendar.timeZone = timeZone
        let day = targetCalendar.dateComponents([.year, .month, .day], from: date)
        let weekdaysString = weekdays.sorted().map(String.init).joined(separator: ",")
        return "\(timeZone.identifier)_\(TimeZone.current.identifier)_\(day.year ?? 0)_\(day.month ?? 0)_\(day.day ?? 0)_\(startMinute)_\(endMinute)_\(weekdaysString)" as NSString
    }

    private func calculateOverlaySegments(startMinute: Int, endMinute: Int, weekdays: Set<Int>) -> [TimeRangeSegment] {
        var targetCalendar = Calendar.current
        targetCalendar.timeZone = timeZone
        let startOfDay = targetCalendar.startOfDay(for: date)

        var segments: [TimeRangeSegment] = []
        var currentSegmentStart: Int?

        for minute in 0..<(24 * 60) {
            let minuteDate = startOfDay.addingTimeInterval(TimeInterval(minute * 60))
            let isAvailable = isDateWithinLocalAvailability(
                at: minuteDate,
                startMinute: startMinute,
                endMinute: endMinute,
                weekdays: weekdays
            )

            if isAvailable {
                if currentSegmentStart == nil {
                    currentSegmentStart = minute
                }
            } else if let segmentStart = currentSegmentStart {
                segments.append(TimeRangeSegment(startMinute: segmentStart, endMinute: minute))
                currentSegmentStart = nil
            }
        }

        if let segmentStart = currentSegmentStart {
            segments.append(TimeRangeSegment(startMinute: segmentStart, endMinute: 24 * 60))
        }

        return mergeMidnightWrappedSegments(segments)
    }

    // If availability continues through midnight, merge tail and head into one continuous segment.
    private func mergeMidnightWrappedSegments(_ segments: [TimeRangeSegment]) -> [TimeRangeSegment] {
        guard
            segments.count >= 2,
            let first = segments.first,
            let last = segments.last,
            first.startMinute == 0,
            last.endMinute == 24 * 60
        else {
            return segments
        }

        let merged = TimeRangeSegment(
            startMinute: last.startMinute,
            endMinute: first.endMinute + 24 * 60
        )

        var result = Array(segments.dropLast().dropFirst())
        result.insert(merged, at: 0)
        return result
    }

    private func isDateWithinLocalAvailability(at date: Date, startMinute: Int, endMinute: Int, weekdays: Set<Int>) -> Bool {
        isDateWithinAvailability(
            at: date,
            in: .current,
            startMinute: startMinute,
            endMinute: endMinute,
            weekdays: weekdays
        )
    }

    private func isDateWithinAvailability(
        at date: Date,
        in timeZone: TimeZone,
        startMinute: Int,
        endMinute: Int,
        weekdays: Set<Int>
    ) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let weekday = calendar.component(.weekday, from: date)
        guard weekdays.contains(weekday) else {
            return false
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return isMinuteWithinAvailability(minuteOfDay, startMinute: startMinute, endMinute: endMinute)
    }

    private func isMinuteWithinAvailability(_ minute: Int, startMinute: Int, endMinute: Int) -> Bool {
        if startMinute == endMinute {
            return true
        }

        if endMinute > startMinute {
            return minute >= startMinute && minute < endMinute
        }

        return minute >= startMinute || minute < endMinute
    }

    private func parseTimeStringToMinute(_ timeString: String) -> Int? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    private func parseWeekdaySet(_ weekdayString: String) -> Set<Int> {
        Set(weekdayString.split(separator: ",").compactMap { Int($0) })
    }

    var body: some View {
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

            ForEach(Array(overlaySegments.enumerated()), id: \.offset) { _, segment in
                TimeOverlayArc(
                    segment: segment,
                    size: size,
                    orbitRadius: orbitRadius,
                    lineWidth: lineWidth
                )
                .blendMode(BlendMode.plusLighter)
            }

            ZStack {
                Circle()
                    .fill(.white)
                    .opacity(isCurrentTimeInOverlay ? 1 : 0)

                Circle()
                    .stroke(.white, lineWidth: 1.5)
                    .opacity(isCurrentTimeInOverlay ? 0 : 0.5)
            }
            .frame(width: markerSize, height: markerSize)
            .offset(y: -orbitRadius)
            .rotationEffect(.degrees(currentTimeAngle))
            .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct TimeOverlayArc: View {
    let segment: TimeOverlayIndicator.TimeRangeSegment
    let size: CGFloat
    let orbitRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        if segment.endMinute > segment.startMinute {
            Path { path in
                path.addArc(
                    center: CGPoint(x: size / 2, y: size / 2),
                    radius: orbitRadius,
                    startAngle: .degrees(Double(segment.startMinute) * 0.25 - 90),
                    endAngle: .degrees(Double(segment.endMinute) * 0.25 - 90),
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
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 24) {
            TimeOverlayIndicator(
                date: Date(),
                timeZone: .current,
                size: 64
            )

            TimeOverlayIndicator(
                date: Date(),
                timeZone: TimeZone(identifier: "Asia/Tokyo") ?? .current,
                size: 64
            )
        }
    }
}
