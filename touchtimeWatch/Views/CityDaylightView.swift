//
//  CityDaylightView.swift
//  touchtimeWatch
//

import SwiftUI

/// The widget's full-color sky ring and the city's daylight duration.
/// Tapping the ring's center trades the duration for the hours around it.
struct CityDaylightView: View {
    let date: Date
    let timeZone: TimeZone
    let isAdjusting: Bool
    var referenceDate: Date? = nil

    @Environment(\.locale) private var locale
    @State private var showsHours = false

    /// The ring's edges, which the border around its hours matches.
    private static let borderWidth: CGFloat = 1.5
    private static let borderOpacity = 0.10

    private var dateString: String {
        date.formatted(
            Date.FormatStyle(locale: locale, timeZone: timeZone)
                .weekday(.abbreviated)
                .day()
        )
    }

    private var daylightDuration: String {
        guard let coordinates = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            return "—"
        }
        let events = SolarCalculator.events(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            date: date,
            timeZone: timeZone
        )
        // Elapsed time also handles daylight-saving changes. Rounding to
        // minutes preserves the calculator's full-day and zero-day polar cases.
        let minutes = max(0, Int((events.sunset.timeIntervalSince(events.sunrise) / 60).rounded()))
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
                        referenceDate: referenceDate,
                        borderWidth: Self.borderWidth,
                        borderOpacity: Self.borderOpacity
                    )
                    .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        ClockTimeText(date: date, timeZone: timeZone, size: .title)

                        Text(dateString)
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
                Text(daylightDuration)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .scenePadding(.navigationBar, edges: .horizontal)
                    .transition(.blurReplace)
                    .accessibilityLabel("Daylight")
                    .accessibilityValue(daylightDuration)
            }
        }
        // The circle's narrow top fits between the toolbar controls,
        // reclaiming the former city-title row without moving the footer.
        .padding(.top, -20)
        .padding(.bottom, 8)
    }
}

/// Every other hour around the outside of the daylight ring, inside a border
/// like the ring's edges. Hidden, they tuck in behind the ring's edge, so
/// they come out from under it.
private struct DaylightRingHours: View {
    /// How far past the ring the hours and their border reach.
    static let bandWidth: CGFloat = 20

    let ringDiameter: CGFloat
    let isVisible: Bool
    let borderWidth: CGFloat
    let borderOpacity: Double

    @Environment(\.locale) private var locale

    var body: some View {
        let bandWidth = isVisible ? Self.bandWidth : 0
        let diameter = ringDiameter + bandWidth * 2
        // Halfway between the ring's edge and the border. Beside the ring the
        // hours lie lengthwise across the band, which is sized to clear them there.
        let radius = (ringDiameter + bandWidth - borderWidth) / 2

        ZStack {
            Circle()
                .strokeBorder(.white.opacity(borderOpacity), lineWidth: borderWidth)
                .blendMode(.plusLighter)
                .frame(width: diameter, height: diameter)

            ForEach(0..<12, id: \.self) { index in
                let hour = index * 2
                // Midnight at the top, clockwise, as on the ring.
                let angle = Double(hour) / 24 * 2 * .pi

                Text(WatchTimeFormat.dialHour(hour, hourCycle: locale.hourCycle))
                    .offset(x: radius * sin(angle), y: -radius * cos(angle))
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .opacity(isVisible ? 1 : 0)
    }
}
