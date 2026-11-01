//
//  CityDaylightView.swift
//  touchtimeWatch
//

import SwiftUI

/// The widget's full-color sky ring and the city's daylight duration.
struct CityDaylightView: View {
    let date: Date
    let timeZone: TimeZone
    let isAdjusting: Bool

    @Environment(\.locale) private var locale

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
                let diameter = max(0, min(geometry.size.width - 16, geometry.size.height))
                let ringWidth = diameter * 0.20
                let holeDiameter = diameter - ringWidth * 2

                ZStack {
                    DaylightRing(
                        date: date,
                        timeZoneIdentifier: timeZone.identifier,
                        size: diameter,
                        ringWidth: ringWidth,
                        monochrome: false,
                        sunAnimation: .interactive(isAdjusting: isAdjusting),
                        borderWidth: 1.5,
                        borderOpacity: 0.10
                    )
                    .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        ClockTimeText(date: date, timeZone: timeZone, size: .medium)

                        Text(dateString)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: holeDiameter * 0.80)
                    .accessibilityElement(children: .combine)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            Text(daylightDuration)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .scenePadding(.navigationBar, edges: .horizontal)
                .accessibilityLabel("Daylight")
                .accessibilityValue(daylightDuration)
        }
        .padding(.bottom, 8)
    }
}
