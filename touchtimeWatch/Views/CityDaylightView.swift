//
//  CityDaylightView.swift
//  touchtimeWatch
//

import SwiftUI

/// The widget's full-color sky ring, and how long until the city's daylight
/// ends or starts. Tapping the ring's center trades the countdown for the
/// hours around it.
struct CityDaylightView: View {
    let date: Date
    let timeZone: TimeZone
    let dateLabel: String
    let isAdjusting: Bool
    var referenceDate: Date? = nil

    @Environment(\.locale) private var locale
    @State private var showsHours = false

    /// The ring's edges, which the border around its hours matches.
    private static let borderWidth: CGFloat = 1.5
    private static let borderOpacity = 0.10

    /// The city's hour now. While the Crown shows another time, now is the
    /// reference date.
    private var currentHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.hour, from: referenceDate ?? date)
    }

    /// How long until the city's daylight ends, or until it next starts.
    private var daylightCountdown: String {
        guard let coordinates = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            return "-"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = calendar.dateInterval(of: .day, for: date),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return "-"
        }
        func events(on moment: Date) -> SolarCalculator.DayEvents {
            SolarCalculator.events(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                date: moment,
                timeZone: timeZone
            )
        }

        let today = events(on: date)
        // The calculator collapses a polar night's sunrise and sunset into
        // noon, and pins a polar day's to the day's edges. Neither is a
        // crossing to count down to.
        let isPolarDay = today.sunrise <= day.start && today.sunset >= day.end.addingTimeInterval(-1)
        guard today.sunrise < today.sunset, !isPolarDay else { return "-" }

        if date < today.sunrise {
            return String(format: String(localized: "Starts in %@", locale: locale), countdown(to: today.sunrise))
        }
        if date < today.sunset {
            return String(format: String(localized: "Ends in %@", locale: locale), countdown(to: today.sunset))
        }
        let next = events(on: tomorrow)
        guard next.sunrise < next.sunset else { return "-" }
        return String(format: String(localized: "Starts in %@", locale: locale), countdown(to: next.sunrise))
    }

    /// Rounded up to whole minutes, so it never reads zero before the event.
    private func countdown(to event: Date) -> String {
        let minutes = max(0, Int((event.timeIntervalSince(date) / 60).rounded(.up)))
        if minutes < 60 {
            return String(format: String(localized: "%d minutes", locale: locale), minutes)
        }
        if minutes % 60 == 0 {
            return String(format: String(localized: "%d hours", locale: locale), minutes / 60)
        }
        return String(
            format: String(localized: "%d hours %d minutes", locale: locale),
            minutes / 60,
            minutes % 60
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                // The hours take over the footer's height, and the ring
                // shrinks a little to make room for them around it.
                let hourBandWidth = showsHours ? DaylightRingHours.bandWidth : 0
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height) - hourBandWidth * 2)
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - ringWidth * 2

                ZStack {
                    // Always laid out, so the hours travel with the ring.
                    DaylightRingHours(
                        ringDiameter: diameter,
                        isVisible: showsHours,
                        currentHour: currentHour,
                        borderWidth: Self.borderWidth,
                        borderOpacity: Self.borderOpacity
                    )
                    .accessibilityHidden(true)

                    DaylightRing(
                        date: date,
                        timeZoneIdentifier: timeZone.identifier,
                        size: diameter,
                        ringWidth: ringWidth,
                        monochrome: false,
                        sunAnimation: .interactive(isAdjusting: isAdjusting),
                        borderWidth: Self.borderWidth,
                        borderOpacity: Self.borderOpacity,
                        nightSunOpacity: 1
                    )
                    .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        ClockTimeText(date: date, timeZone: timeZone, size: .title)

                        Text(dateLabel)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: holeDiameter * 0.80)
                    .accessibilityElement(children: .combine)
                    .frame(width: holeDiameter, height: holeDiameter)
                    .contentShape(.circle)
                    .onTapGesture {
                        withAnimation(.smooth) {
                            showsHours.toggle()
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            if !showsHours {
                Text(daylightCountdown)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText(countsDown: true))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .scenePadding(.navigationBar, edges: .horizontal)
                    .transition(.blurReplace)
                    .accessibilityLabel("Daylight")
                    .accessibilityValue(daylightCountdown)
            }
        }
        // The circle's narrow top fits between the toolbar controls,
        // reclaiming the former city-title row without moving the footer.
        .padding(.top, -20)
        .padding(.bottom, 8)
    }
}

/// Every other hour around the outside of the daylight ring, and the current
/// hour on a pill, inside a border like the ring's edges. The border comes out
/// from under the ring's edge as the hours blur in, like the footer they
/// replace.
private struct DaylightRingHours: View {
    /// How far past the ring the hours and their border reach.
    static let bandWidth: CGFloat = 16
    /// The current hour's pill, end to end along the ring.
    private static let pillLength: CGFloat = 24
    /// Half a two-digit hour's width, plus space between it and the pill.
    private static let hourClearance: CGFloat = 10

    let ringDiameter: CGFloat
    let isVisible: Bool
    let currentHour: Int
    let borderWidth: CGFloat
    let borderOpacity: Double

    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat

    /// Across the ring's bottom half, an hour turns over to read left to right
    /// rather than upside down.
    static func isTurnedOver(_ hour: Int) -> Bool {
        hour > 6 && hour < 18
    }

    var body: some View {
        let bandWidth = isVisible ? Self.bandWidth : 0
        let diameter = ringDiameter + bandWidth * 2
        // Halfway between the ring's edge and the border.
        let radius = (ringDiameter + bandWidth - borderWidth) / 2
        // An odd hour's pill sits between two marked hours, which make way
        // for it where the ring is too small for all three.
        let hourSpacing = radius * 2 * sin(.pi / 24)
        let makesWayForPill = hourSpacing < Self.pillLength / 2 + Self.hourClearance

        ZStack {
            Circle()
                .strokeBorder(.white.opacity(borderOpacity), lineWidth: borderWidth)
                .blendMode(.plusLighter)
                .frame(width: diameter, height: diameter)
                .opacity(isVisible ? 1 : 0)

            // Transitioning inside the placement scales each hour, and the
            // pill, about itself rather than the ring's center.
            ForEach(0..<12, id: \.self) { index in
                let hour = index * 2
                let distance = abs(hour - currentHour)
                let yieldsToPill = distance == 0 || makesWayForPill && min(distance, 24 - distance) == 1

                ZStack {
                    if isVisible, !yieldsToPill {
                        Text(WatchTimeFormat.dialHour(hour, use24HourFormat: use24HourFormat))
                            .transition(.blurReplace)
                    }
                }
                .placed(atHour: hour, radius: radius)
            }

            ZStack {
                if isVisible {
                    Text(WatchTimeFormat.dialHour(currentHour, use24HourFormat: use24HourFormat))
                        .foregroundStyle(.black)
                        .background(.white, in: HourPill(
                            radius: radius,
                            length: Self.pillLength,
                            // From the ring's edge to the border, overlapping
                            // each a little so no seam shows between them.
                            thickness: Self.bandWidth - borderWidth + 1,
                            isTurnedOver: Self.isTurnedOver(currentHour)
                        ))
                        .transition(.blurReplace)
                }
            }
            .placed(atHour: currentHour, radius: radius)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
    }
}

private extension View {
    /// At an hour around a circle of `radius`, turned along it.
    func placed(atHour hour: Int, radius: CGFloat) -> some View {
        // Midnight at the top, clockwise, as on the ring.
        let angle = Double(hour) / 24 * 2 * .pi
        return rotationEffect(.radians(DaylightRingHours.isTurnedOver(hour) ? angle - .pi : angle))
            .offset(x: radius * sin(angle), y: -radius * cos(angle))
    }
}

/// A pill bent along a circle through its middle, centered below it, or
/// above it once turned over across the ring's bottom.
struct HourPill: Shape {
    let radius: CGFloat
    let length: CGFloat
    let thickness: CGFloat
    let isTurnedOver: Bool

    func path(in rect: CGRect) -> Path {
        let side: CGFloat = isTurnedOver ? -1 : 1
        let center = CGPoint(x: rect.midX, y: rect.midY + side * radius)
        // The round ends reach half the thickness past each end of the arc.
        let sweep = (length - thickness) / radius
        var arc = Path()
        arc.addRelativeArc(
            center: center,
            radius: radius,
            startAngle: .radians(-side * .pi / 2 - sweep / 2),
            delta: .radians(sweep)
        )
        return arc.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}
